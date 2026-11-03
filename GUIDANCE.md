# .NET on Wodby

What Wodby sets up for an application that runs on this service. Check it before changing the build, the port or connection settings in the code.

## Build and start

The service's Dockerfile publishes the repository with the .NET SDK and runs the result on the service image:

1. it picks the project: the `DOTNET_PROJECT` build argument, or else the only project file (`*.csproj`, `*.fsproj`, `*.vbproj`) at the repository's root, or else the only one in a `src/<name>/` directory. Among several, it takes the only runnable one: a `Microsoft.NET.Sdk.Web` or `Microsoft.NET.Sdk.Worker` project, or one with `<OutputType>Exe</OutputType>`. Otherwise the build fails;
2. runs `dotnet publish -c Release` for it, with `RestoreLockedMode` when the repository has a `packages.lock.json`;
3. copies the output to `/usr/src/app` in the service image, which has the ASP.NET Core runtime but no SDK.

The container starts `dotnet-app`, which runs the assembly named by `DOTNET_APP`, or else the one whose `*.runtimeconfig.json` is the only one in `/usr/src/app`. The build stage uses the newest .NET SDK, which also builds projects for earlier .NET versions; the project's `TargetFramework` must match the service's .NET version. A pipeline that passes a Dockerfile from the repository (`wodby ci build dotnet -f Dockerfile`) uses that file instead; its final stage must be `FROM ${WODBY_BASE_IMAGE}`.

- The application must listen on port 8080, on all interfaces. That is the port of the service's HTTP endpoint and the image's `ASPNETCORE_HTTP_PORTS`, which ASP.NET Core reads. Do not set URLs in `launchSettings.json` or code for deployed environments: `launchSettings.json` is not used by a published application.
- The service is ready once the port accepts connections.
- `DOTNET_ENVIRONMENT` is `Development` in development environments and unset elsewhere, so applications run as `Production`.
- The image has ICU and full culture data; globalization-invariant mode is off.
- The service declares no volume of its own: files written inside the container are lost when it is replaced. That includes ASP.NET Core Data Protection keys, which by default live in the container's home: cookies and antiforgery tokens stop being valid after a deployment and differ between replicas. Persist the keys to Redis or a database when the application uses them.

## Linked services

Links to other services reach the application as environment variables. Nothing in the image reads them: the application reads them itself, for example with `NpgsqlConnectionStringBuilder` or `MySqlConnectionStringBuilder`, which quote values correctly. Do not hardcode hosts or credentials.

| Link | Variables |
| --- | --- |
| Database (MariaDB, MySQL or PostgreSQL) | `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD`, `DB_DRIVER` |
| Mail | `SMTP_HOST`, `SMTP_PORT` |
| Redis or Valkey | `REDIS_HOST`, `REDIS_PORT`, `REDIS_PASSWORD` |

All three links are optional. A variable is present only while its link exists and the linked service is enabled. The mail link carries no credentials.

## Environment

- `WODBY_HOSTS` is a JSON array of the environment's hosts, not a comma-separated string. `WODBY_PRIMARY_HOST` and `WODBY_PRIMARY_URL` are the canonical ones for links generated outside a request.
- `WODBY_APP_SERVICE_NAME` is this service's host name inside the environment. Other services reach the application at that name on port 8080.
- `WODBY_ENV_TYPE` tells a development environment from a production-like one.
- Requests arrive through Wodby's gateway, which sets `X-Forwarded-For` and `X-Forwarded-Proto`.

## In a development workspace

- The checkout is mounted at `/usr/src/app` and the container runs the project with `dotnet watch`. A change is applied to the running application with Hot Reload, or the application is rebuilt and restarted when it can't be applied, in the same container, usually within a few seconds. Nothing has to be restarted or deployed for a code change. A build that fails leaves the running application up; the compiler's errors are in the service's logs.
- The project is chosen as in the build; `WORKSPACE_DOTNET_PROJECT` on the service selects another one, such as `src/Api/Api.csproj`. `WORKSPACE_DOTNET_COMMAND` replaces the start command.
- Workspace setup restores dependencies with `workspace-dotnet prepare`: the solution's when there is exactly one `*.sln` or `*.slnx` at the root, otherwise the project's, and the local tools of `.config/dotnet-tools.json`. With a `packages.lock.json`, restores fail instead of rewriting it.
- `DOTNET_ENVIRONMENT` is `Development` unless the service sets it, and `launchSettings.json` is not used. Browser refresh is off: reload the page by hand.
- NuGet packages are kept in `.wodby-workspace/nuget` in the checkout. `.wodby-workspace/`, `bin/` and `obj/` are kept out of Git status without touching `.gitignore`.
- A change to variables or linked services still needs a deployment of the environment.

## Check the result

- `curl -s -o /dev/null -w '%{http_code}' localhost:8080` from the container shows whether the application answers on the expected port.
- `dotnet build` in the checkout shows compile errors at once; the service's logs show them too when a change does not appear.
