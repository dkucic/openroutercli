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
The script checks for the existance of OPENROUTER_API_KEY environment variable. If variable does not exist or
has no value stored the script attempts to fetch the api key via pass. Variable is obtaine by referencing the pass entry
and parsing `OPENROUTER_API_KEY=$(pass show registrations/openrouter | grep API | cut -d ':' -f 2 | xargs)`. 
If you use pass adjust adjust the extraction and parsing in accordance to your organizational and entry formats.
Environmental variable approach was added for the purpose of containerization.

## Docker 

Pull the automatically built image
```sh
docker pull ghcr.io/dkucic/openroutercli:latest
```

Run the container
```sh
docker run --rm -e OPENROUTER_API_KEY="*****" openroutercli:latest
```

### _Dockerfile_

Build
```sh
docker build . -t openroutercli:latest
```

TODO: Add support for the attachments
