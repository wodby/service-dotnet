# Publishes the repository's .NET project with the SDK and runs the result on the service image.
ARG WODBY_BASE_IMAGE
# The newest SDK also builds projects that target earlier .NET versions.
ARG DOTNET_SDK_IMAGE=mcr.microsoft.com/dotnet/sdk:10.0-alpine

FROM ${DOTNET_SDK_IMAGE} AS build

ARG COPY_FROM
# The project to publish. Without it: the only project file at the repository's root, or else the
# only one in a src/<name>/ directory; among several, the only runnable one (a web or worker SDK
# project, or an executable).
ARG DOTNET_PROJECT

COPY ${COPY_FROM} /src
WORKDIR /src

RUN set -eu; \
    project="${DOTNET_PROJECT:-}"; \
    if [ -z "${project}" ]; then \
        found=$(find . -maxdepth 1 -type f \( -name '*.csproj' -o -name '*.fsproj' -o -name '*.vbproj' \) | sort); \
        if [ -z "${found}" ] && [ -d src ]; then \
            found=$(find ./src -mindepth 2 -maxdepth 2 -type f \( -name '*.csproj' -o -name '*.fsproj' -o -name '*.vbproj' \) | sort); \
        fi; \
        if [ "$(printf '%s' "${found}" | grep -c .)" -gt 1 ]; then \
            found=$(printf '%s\n' "${found}" | while read -r file; do \
                if grep -qE 'Sdk="Microsoft\.NET\.Sdk\.(Web|Worker)"|<OutputType>[[:space:]]*(Exe|WinExe)[[:space:]]*<' "${file}"; then printf '%s\n' "${file}"; fi; \
            done); \
        fi; \
        count=$(printf '%s' "${found}" | grep -c . || true); \
        if [ "${count}" != 1 ]; then \
            echo "Found ${count} runnable projects at the repository's root or in src/<name>/; set the DOTNET_PROJECT build argument" >&2; \
            exit 1; \
        fi; \
        project="${found}"; \
    fi; \
    # A NuGet lock file in the repository makes restore fail rather than rewrite it. \
    locked=""; \
    if [ -n "$(find . \( -name bin -o -name obj \) -prune -o -name packages.lock.json -print | head -n 1)" ]; then \
        locked="-p:RestoreLockedMode=true"; \
    fi; \
    dotnet publish "${project}" -c Release -o /out ${locked}

FROM ${WODBY_BASE_IMAGE}

COPY --from=build --chown=wodby:wodby /out /usr/src/app

CMD ["dotnet-app"]
