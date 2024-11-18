import * as core from '@actions/core';
import * as github from '@actions/github';
import axios from 'axios';

async function run() {
  try {
    const token = core.getInput('GITHUB_TOKEN');
    const copilotApiKey = core.getInput('COPILOT_API_KEY');
    const octokit = github.getOctokit(token);
    const context = github.context;

    if (context.payload.pull_request == null) {
      core.setFailed('No pull request found.');
      return;
    }

    const prNumber = context.payload.pull_request.number;
    const { data: files } = await octokit.rest.pulls.listFiles({
      owner: context.repo.owner,
      repo: context.repo.repo,
      pull_number: prNumber,
    });

    for (const file of files) {
      if (file.status === 'added' || file.status === 'modified') {
        const response = await axios.post('https://api.githubcopilot.com/v1/review', {
          apiKey: copilotApiKey,
          filePath: file.filename,
          fileContent: file.patch,
        });

        const comments = response.data.comments;
        for (const comment of comments) {
          await octokit.rest.pulls.createReviewComment({
            owner: context.repo.owner,
            repo: context.repo.repo,
            pull_number: prNumber,
            body: comment.text,
            path: file.filename,
            position: comment.position,
          });
        }
      }
    }
  } catch (error) {
    core.setFailed(error.message);
  }
}

run();
