# Weather App

## Prerequisites
- Docker CLI must be installed
- Azure CLI must be installed
- GitHub CLI must be installed and logged in (`gh auth login`), used to configure the deploy credential
- You must have access to an active Azure account
- Azure CLI must be logged in to said Azure account (`az login`)

## Setup

1. Clone the repository (`git clone git@github.com:Jelcoo/CCDWeatherApp.git`)
2. Copy `.env.example` to `.env`
3. Modify the contents of `.env` to your liking
  - `ACCESS_TOKEN` must be set.
4. Run `./infra/deploy.sh`

## Post Deployment
When the deploy command finishes, there should be a application URL printed out. This is your endpoint for reaching the
API. The API documentation is available on `<app-url>/api-docs/`.

To make requests to the weather API, you must set the `Authorization: Bearer <ACCESS_TOKEN>` header.
