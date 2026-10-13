// The workflows in .github/workflows are generated from here. Run
// `yarn build` in this directory and commit both sides.
import { App, Job, RunnerLabel, Stack, Workflow } from '@factbird/cdkactions';

const app = new App({ createValidateWorkflow: false, outdir: '../workflows' });
const stack = new Stack(app, 'devkit');

/**
 * Weekly, because Dependabot skips the FlakeHub nixpkgs input and updates
 * every other one.
 *
 * The repository is public, so the organization's GitHub App secrets do not
 * reach it and the pull request is opened with GITHUB_TOKEN. GitHub starts no
 * workflow for events caused by GITHUB_TOKEN, which the action's default pull
 * request body tells the reader.
 */
const updateNixpkgs = new Workflow(stack, 'update-nixpkgs', {
  name: 'update nixpkgs',
  on: {
    schedule: [{ cron: '0 4 * * 1' }],
    workflowDispatch: null,
  },
  permissions: { contents: 'read' },
});

new Job(updateNixpkgs, 'update', {
  runsOn: RunnerLabel.UBUNTU_LATEST,
  permissions: { contents: 'write', pullRequests: 'write' },
  steps: [
    { uses: 'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1' }, // v7.0.1
    {
      name: 'Install Nix',
      uses: 'DeterminateSystems/determinate-nix-action@d0c908e6cbe9f89f36ed8205a3ab6f092636916a', // v3.23.1
    },
    {
      name: 'Update nixpkgs and open pull request',
      uses: 'DeterminateSystems/update-flake-lock@da03c0f078bc4b2c37ee4f7e072d34bf8f188bb3', // v29
      with: {
        inputs: 'nixpkgs',
        branch: 'chore/update-nixpkgs',
        'commit-msg': 'chore(nix): update nixpkgs',
        'pr-title': 'chore(nix): update nixpkgs',
      },
    },
  ],
});

app.synth();
