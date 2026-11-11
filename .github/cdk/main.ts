// The workflows in .github/workflows are generated from here. Run
// `yarn build` in this directory and commit both sides.
import {
  App,
  checkoutV7,
  DependabotActionPinSync,
  determinateNixV3,
  Job,
  RunnerLabel,
  Stack,
  setupNodeV6,
  updateFlakeLockV29,
  Workflow,
} from '@factbird/cdkactions';

const checkout = checkoutV7.pinned('3d3c42e5aac5ba805825da76410c181273ba90b1', 'v7.0.1');
const determinateNix = determinateNixV3.pinned('d0c908e6cbe9f89f36ed8205a3ab6f092636916a', 'v3.23.1');
const updateFlakeLock = updateFlakeLockV29.pinned('da03c0f078bc4b2c37ee4f7e072d34bf8f188bb3', 'v29');
const setupNode = setupNodeV6.pinned('249970729cb0ef3589644e2896645e5dc5ba9c38', 'v6.5.0');

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
    checkout({ id: 'checkout' }),
    determinateNix({ name: 'Install Nix' }),
    updateFlakeLock({
      id: 'update-flake-lock',
      name: 'Update nixpkgs and open pull request',
      with: {
        inputs: 'nixpkgs',
        branch: 'chore/update-nixpkgs',
        commitMsg: 'chore(nix): update nixpkgs',
        prTitle: 'chore(nix): update nixpkgs',
      },
    }),
  ],
});

// The CLI and the synth run from the repository root, while this package
// keeps its own node_modules.
new DependabotActionPinSync(stack, 'dependabot-action-pin-sync', {
  sources: ['.github/cdk/main.ts'],
  cliCommand: '.github/cdk/node_modules/.bin/cdkactions',
  synthCommand: 'yarn --cwd .github/cdk build',
  setupSteps: [
    setupNode({ id: 'setup-node', with: { nodeVersion: '24' } }),
    { name: 'Install', run: 'corepack enable && yarn --cwd .github/cdk install --immutable' },
  ],
});

app.synth();
