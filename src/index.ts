import * as core from '@actions/core';
import * as github from '@actions/github';
import axios from 'axios';

async function run() {
  try {
    const token = process.env.GITHUB_TOKEN;
    const claudeApiKey = process.env.CLAUDE_API_KEY;
    
    if (!claudeApiKey) {
      throw new Error("CLAUDE_API_KEY is required");
    }

    if (!token) {
      throw new Error("GIT_TOKEN is required");
    } 
  


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
        const response = await axios.post('https://api.claude.com/v1/review', {
          apiKey: claudeApiKey,
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
    if (error instanceof Error) {
      core.setFailed(error.message);
    } else {
      core.setFailed('An unknown error occurred');
    }
  }
}

run();