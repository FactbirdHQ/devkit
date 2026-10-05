import { App, Job, Stack, Workflow } from '@factbird/cdkactions';

const app = new App({ createValidateWorkflow: false, outdir: '../.github/workflows' });
const stack = new Stack(app, 'fixture');
const workflow = new Workflow(stack, 'ci', { on: 'push', name: 'CI', env: { B: '1', A: '2' } });
new Job(workflow, 'build', {
  runsOn: 'ubuntu-latest',
  steps: [{ name: '🚀 Build', run: 'echo build' }],
});
app.synth();
