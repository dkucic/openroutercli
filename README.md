# openroutercli
Openrouter API wrapper with clean command line interface

## _openroutercli.sh_

The bash script exposed openrouter functionality behind coherent command line api.

```text
OpenRouter API CLI Interface

Usage: ./openroutercli.sh [options]

Options:
  -m <model>           Specify the model (default: anthropic/claude-3-haiku)
  -s <system_prompt>   Set custom system prompt
  -u <user_prompt>     User prompt/question (required unless stdin is provided)
  -l                   List available models
  -c                   Check API credit usage and credits remaining
  -d                   Output response in markdown format
  -t                   Enable streaming mode for real-time responses
  -h                   Display this help message

Examples:
  ./openroutercli.sh -u "Explain quantum computing"
  ./openroutercli.sh -m anthropic/claude-3-opus -u "Write a short story" -d
  ./openroutercli.sh -u "Tell me a long story" -t
  cat prompt.txt | ./openroutercli.sh -m anthropic/claude-3-sonnet
```
## _Dockerfile_

For the purpose of running in container script has been extended to also check for the existance of 
**OPENROUTER_API_KEY** environment variable.

Build
```sh
docker build . -t openroutercli:latest
```
Run
```sh
docker run --rm -e OPENROUTER_API_KEY="*****" openroutercli:latest
```
