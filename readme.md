## Code::Stats for Micro Editor

Micro plugin that counts your keypresses and saves statistics to [Code::Stats](https://codestats.net).

### Requirements
- curl

### Installation
1. Open [Micro Config](https://github.com/zyedidia/micro/blob/master/runtime/help/options.md#options) in a text editor
2. Add the following options to the config.
  ```json
  {
    "pluginrepos": ["https://raw.githubusercontent.com/redfire75369/code-stats-micro/master/repo.json"],
    "codestats.apikey": "<ENTER API KEY HERE>"
  }
  ```
3. If you want to use a different Code::Stats server, add a `"codestats.apiurl"` key with the url.
4. Run `micro -plugin install codestats`.
