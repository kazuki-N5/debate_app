import yaml

ci_yaml = """
name: Supabase CI (PR Validation)

on:
  pull_request:
    branches:
      - main
    paths:
      - 'supabase/**'

concurrency:
  group: supabase-ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Setup Supabase CLI
        uses: supabase/setup-cli@v1
        with:
          version: latest

      - name: Start Local Supabase Stack
        run: supabase start

      - name: Verify Migration Replay (db reset)
        run: supabase db reset

      - name: Run Static Security & Performance Lint (db lint)
        run: supabase db lint

      - name: Run RLS Unit Tests (test db)
        run: supabase test db

      - name: Stop Supabase Stack
        if: always()
        run: supabase stop
"""

deploy_yaml = """
name: Deploy Supabase Migrations (Production)

on:
  push:
    branches:
      - main
    paths:
      - 'supabase/migrations/**'
  workflow_dispatch:

concurrency:
  group: supabase-deploy-${{ github.ref }}
  cancel-in-progress: false

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout Repository
        uses: actions/checkout@v4

      - name: Setup Supabase CLI
        uses: supabase/setup-cli@v1
        with:
          version: latest

      - name: Deploy Migrations to Supabase Production
        env:
          SUPABASE_ACCESS_TOKEN: ${{ secrets.SUPABASE_ACCESS_TOKEN }}
          SUPABASE_DB_PASSWORD: ${{ secrets.SUPABASE_DB_PASSWORD }}
          SUPABASE_PROJECT_ID: ${{ secrets.SUPABASE_PROJECT_ID }}
        run: |
          supabase link --project-ref $SUPABASE_PROJECT_ID
          supabase db push --password "$SUPABASE_DB_PASSWORD"
"""

try:
    ci_res = yaml.safe_load(ci_yaml)
    print("CI YAML is VALID!")
except Exception as e:
    print("CI YAML ERROR:", e)

try:
    deploy_res = yaml.safe_load(deploy_yaml)
    print("Deploy YAML is VALID!")
except Exception as e:
    print("Deploy YAML ERROR:", e)
