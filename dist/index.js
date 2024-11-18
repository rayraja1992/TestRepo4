"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
Object.defineProperty(exports, "__esModule", { value: true });
const core = require("@actions/core");
const github = require("@actions/github");
const axios_1 = require("axios");
function run() {
    return __awaiter(this, void 0, void 0, function* () {
        try {
            const token = core.getInput('GIT_TOKEN');
            const claudeApiKey = core.getInput('CLAUDE_API_KEY');
            if (!token) {
                throw new Error("GIT_TOKEN is required");
            }
            if (!claudeApiKey) {
                throw new Error("CLAUDE_API_KEY is required");
            }
            const octokit = github.getOctokit(token);
            const context = github.context;
            if (context.payload.pull_request == null) {
                core.setFailed('No pull request found.');
                return;
            }
            const prNumber = context.payload.pull_request.number;
            const { data: files } = yield octokit.rest.pulls.listFiles({
                owner: context.repo.owner,
                repo: context.repo.repo,
                pull_number: prNumber,
            });
            for (const file of files) {
                if (file.status === 'added' || file.status === 'modified') {
                    const response = yield axios_1.default.post('https://api.claude.com/v1/review', {
                        apiKey: claudeApiKey,
                        filePath: file.filename,
                        fileContent: file.patch,
                    });
                    const comments = response.data.comments;
                    for (const comment of comments) {
                        yield octokit.rest.pulls.createReviewComment({
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
        }
        catch (error) {
            if (error instanceof Error) {
                core.setFailed(error.message);
            }
            else {
                core.setFailed('An unknown error occurred');
            }
        }
    });
}
run();
