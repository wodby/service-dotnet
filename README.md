# .NET service for Kubernetes on Wodby

Build and run .NET applications on Kubernetes with Wodby.

This repository defines the Wodby service manifests and operational
configuration for .NET.

- [Browse Wodby services](https://wodby.com/services)
- [Wodby service documentation](https://wodby.com/docs/2.0/services/)
- [Service manifest reference](https://wodby.com/docs/2.0/services/template/)

## Start with a boilerplate

Use the boilerplate of the service that inherits from this one:

- [ASP.NET Core boilerplate](https://github.com/wodby/aspnetcore-boilerplate)

## Services and stacks using this service

- [ASP.NET Core service](https://github.com/wodby/service-aspnetcore)
- [ASP.NET Core application stack](https://github.com/wodby/stack-aspnetcore)

## Service overview

| Property | Manifest configuration |
| --- | --- |
| Service name | `dotnet` |
| Type | Application service |
| Versions | `10.0` by default |
| Workloads | `main` (Deployment), primary; scalable |
| Containers | `dotnet` using `wodby/dotnet`, build target |
| Endpoints | `dotnet`: HTTP 8080 (main) |
| Service links | DBMS (`db`), optional, Mail Transfer Agent (`sendmail`), optional, Redis, optional |
| Application build | Git source connection enabled; Dockerfile: `Dockerfile` |
| Helm | chart `oci://registry-1.docker.io/wodby/stateless`; version `0.4.0` |
| Configuration | 1 integration slots |

## Use this service

Reference `dotnet` from a custom Wodby stack, or use the
[ASP.NET Core service](https://github.com/wodby/service-aspnetcore) for web applications.

A service is a reusable component and does not deploy by itself. The stack
defines its links, settings, versions, resources, and relationship to the rest
of the application.

## Build

The service's `Dockerfile` publishes the repository with the .NET SDK and copies
the output into `wodby/dotnet`, which has the ASP.NET Core runtime but no SDK.
It publishes the `DOTNET_PROJECT` build argument, or else the only project file
at the repository's root, or else the only one in a `src/<name>/` directory;
among several, the only runnable one. A repository with a `packages.lock.json`
restores in locked mode. The container runs `dotnet-app`, which starts the
published entry assembly.

## Maintain a custom version

1. Fork this repository.
2. Edit the service manifest and referenced files.
3. Import the repository as a [Git-backed service](https://wodby.com/docs/2.0/services/create/#create-a-git-backed-service).
4. Reference the service from a stack manifest.

Keep service, workload, container, endpoint, link, volume, config, and
derivative names stable unless dependent stacks and app-level overrides are
updated at the same time.

Validate the manifests with:

```bash
wodby service validate-manifest service.yml --org <org-id>
```

See the [service manifest reference](https://wodby.com/docs/2.0/services/template/) and the [managed services index](https://github.com/wodby/services).

## Development workspaces

`workspace-dotnet prepare` restores the solution's or the project's
dependencies and the local tools of a `dotnet-tools.json` manifest.
`workspace-dotnet start` runs the project with `dotnet watch`, which applies
changes with Hot Reload or rebuilds and restarts the application; the checkout
is polled. `WORKSPACE_DOTNET_WATCH=0` turns watching off,
`WORKSPACE_DOTNET_PROJECT` selects the project and `WORKSPACE_DOTNET_COMMAND`
overrides startup. NuGet packages are kept in `.wodby-workspace/nuget`; `bin/`
and `obj/` are excluded from Git status. With a `packages.lock.json`, restores
fail instead of rewriting it.

Requires a runtime image declaring workspace contract version 1. Ordinary and development option tags must use matching revisions.
