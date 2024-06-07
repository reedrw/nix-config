{ pkgs, ... }:

{
  home.packages = [ pkgs.mods ];

  xdg.configFile."mods/mods.yml".text = builtins.toJSON {
    # Default model (gpt-3.5-turbo, gpt-4, ggml-gpt4all-j...).
    default-model = "llama3";

    # Text to append when using the -f flag.
    format-text = {
      markdown = "Format the response as markdown without enclosing backticks.";
      json = "Format the response as json without enclosing backticks.";
    };

    # List of predefined system messages that can be used as roles.
    roles = {
      default = [];
      shell = [
        "you are a shell expert"
        "you do not explain anything"
        "you simply output one liners to solve the problems you're asked"
        "you do not provide any explanation whatsoever, ONLY the command"
      ];
    };

    # Ask for the response to be formatted as markdown unless otherwise set.
    format = false;

    # System role to use.
    role = "default";

    # Render output as raw text when connected to a TTY.
    raw = false;

    # Quiet mode (hide the spinner while loading and stderr messages for success).
    quiet = false;

    # Temperature (randomness) of results, from 0.0 to 2.0.
    temp = 1.0;

    # TopP, an alternative to temperature that narrows response, from 0.0 to 1.0.
    topp = 1.0;

    # Turn off the client-side limit on the size of the input into the model.
    no-limit = false;

    # Wrap formatted output at specific width (default is 80)
    word-wrap = 80;

    # Include the prompt from the arguments in the response.
    include-prompt-args = false;

    # Include the prompt from the arguments and stdin, truncate stdin to specified number of lines.
    include-prompt = 0;

    # Maximum number of times to retry API calls.
    max-retries = 5;

    # Your desired level of fanciness.
    fanciness = 10;

    # Text to show while generating.
    status-text = "Generating";

    # Default character limit on input to model.
    max-input-chars = 12250;

    # Maximum number of tokens in response.
    #max-tokens = 100;

    # Aliases and endpoints for OpenAI compatible REST API.
    apis = {
      ollama = {
        base-url = "http://localhost:11434/api";
        models = {
          "llama3" = {
            aliases = ["llama3"];
            max-input-chars = 650000;
          };
        };
      };
    };
  };

}
