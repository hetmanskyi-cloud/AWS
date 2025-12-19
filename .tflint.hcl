# This is a basic configuration file for TFLint.
# It enables the core ruleset and the plugin for AWS.

# --- Plugin Configuration --- #
# Plugins are the main strength of TFLint. They provide rules specific to cloud providers.
#
# After adding or changing a plugin, you MUST run `tflint --init` in your terminal
# to download and install it.

plugin "aws" {
  enabled = true
  version = "0.44.0" # Pinning the latest stable version of the AWS plugin
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}
