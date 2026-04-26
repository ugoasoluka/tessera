# Contributing to Tessera

Thank you for your interest in contributing! This guide will help you get started.

## Code of Conduct

Be respectful, inclusive, and constructive in all interactions. We welcome contributions from everyone regardless of background or experience level.

## Getting Started

### Prerequisites

- **Git** for version control
- **Python 3.9+** with `uv` for dependency management
- **Terraform >= 1.5** for infrastructure changes
- **Helm >= 3.13** for Kubernetes charts
- **Docker** for building container images (optional—CI does this automatically)
- **kubectl** and AWS CLI v2 for cluster operations
- Familiarity with the [README.md](./README.md) and [DESIGN.md](./DESIGN.md)

### Setting Up Your Development Environment

1. **Fork and clone the repository:**

   ```bash
   git clone https://github.com/<your-username>/tessera.git
   cd tessera
   ```

2. **Create a feature branch:**

   ```bash
   git checkout -b feature/your-feature-name
   ```

3. **Install Python dependencies** (for app development):

   ```bash
   # For slack-bot
   cd apps/slack-bot
   uv sync
   cd ../..

   # For temporal-worker
   cd apps/temporal-worker
   uv sync
   cd ../..
   ```

4. **Set up AWS credentials** (for infrastructure work):

   ```bash
   aws configure --profile tessera
   aws sts get-caller-identity --profile tessera  # verify access
   ```

## Making Changes

### Code Changes

- **Python code**: Follow PEP 8. The project uses `pyproject.toml` for configuration.
- **Tests**: Add tests for new functionality. Run with `python -m pytest` in the relevant app directory.
- **Type hints**: Use type annotations in Python code for clarity.
- **Docstrings**: Add docstrings to functions and classes.

### Infrastructure Changes

- **Terraform**: Keep modules small and focused. Run `terraform plan` before `apply`.
- **Helm charts**: Follow Helm best practices. Validate with `helm lint`.
- **Secrets**: Never commit credentials, API keys, or sensitive data. Use AWS Secrets Manager.

### Documentation Changes

- **Keep it current**: If you change behavior, update the relevant docs.
- **Markdown**: Use clear headings, code blocks, and examples.
- **Links**: Ensure all internal links work and are relative.

## Submitting Changes

### Before You Push

1. **Format and lint your code:**

   ```bash
   # Python (adjust path as needed)
   cd apps/temporal-worker
   python -m black src/
   python -m isort src/
   cd ../..
   ```

2. **Test your changes locally:**

   ```bash
   # Run any existing test suite
   cd apps/slack-bot
   python -m pytest
   cd ../..
   ```

3. **Update DESIGN.md** if your change affects decisions, trade-offs, or future work.

4. **Commit with clear messages:**

   ```bash
   git commit -m "brief summary

   - More detail here
   - Explain why this change was needed
   - Reference any issues or decisions"
   ```

### Opening a Pull Request

1. **Push your branch** to your fork:

   ```bash
   git push origin feature/your-feature-name
   ```

2. **Create a PR** on GitHub with:
   - A clear title (<72 characters)
   - A description of what changed and why
   - A reference to any related issues (e.g., "Fixes #123")
   - Screenshots or logs if applicable

3. **Address feedback** promptly and push updates to your branch.

## PR Review Checklist

Your PR is more likely to be merged quickly if it:

- [ ] Has a clear, concise title
- [ ] Includes a description of what and why
- [ ] Makes minimal, focused changes
- [ ] Includes tests (if applicable)
- [ ] Updates documentation (if applicable)
- [ ] Follows existing code style
- [ ] Does not introduce secrets or credentials
- [ ] Passes CI checks (build, tests, lint)

## Areas Where Help Is Needed

- **Documentation**: Expanding guides, examples, and troubleshooting.
- **Tests**: Adding unit and integration tests.
- **Performance**: Optimizing workflows, startup times, or resource usage.
- **Infrastructure**: Improving terraform modules, helm charts, or deployment automation.
- **Bug fixes**: Tackling open issues.

## Reporting Issues

When reporting a bug:

1. **Describe the problem** clearly
2. **Provide steps to reproduce** (or a minimal example)
3. **Include relevant logs** and error messages
4. **Mention your environment** (Python version, AWS region, K8s cluster version, etc.)

## Architecture Overview (for contributors)

For in-depth understanding:

- **`DESIGN.md`**: Design decisions, trade-offs, limitations, and future work
- **`README.md`**: Deployment guide and architectural diagram
- **`apps/slack-bot/`**: Slack bot entrypoint (Bolt + Socket Mode + Temporal client)
- **`apps/temporal-worker/`**: Agent implementation (Pydantic AI + Temporal worker)
- **`terraform/`**: AWS infrastructure (VPC, EKS, RDS, ECR, IAM, Secrets Manager)
- **`helm/`**: Kubernetes deployments (Temporal, bot, worker, add-ons)

## Testing Your Changes

### Local Python Testing

```bash
cd apps/temporal-worker
python -m pytest src/  # or whatever test discovery pattern is used
```

### Terraform Plan

```bash
cd terraform/main
terraform plan
```

### Helm Validation

```bash
helm lint helm/slack-bot
helm lint helm/temporal-worker
```

### End-to-End (if you have a test cluster)

Deploy to a staging environment and test the full Slack → Temporal → GitHub → Slack loop.

## Licensing

By contributing, you agree that your contributions are licensed under the same license as the project (check LICENSE file or ask the maintainers).

## Questions?

- Check `DESIGN.md` for architecture and design context
- Review existing PRs and issues for similar discussions
- Open a GitHub discussion or issue to ask

Thank you for contributing to Tessera! 🙏
