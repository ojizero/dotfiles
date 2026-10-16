# T3 prompt recipes

Use dotfiles as the task working directory. These are prompts for agent tasks, not shell schedules. Do not create or enable tasks unless requested. Choose the task's runner model in T3.

Daily, interval `{"type":"interval","everyMs":86400000}`:

> Use the repository-local housekeeping skill. Run its configured daily collector. Return a short healthy no-op; on warning, urgent or unknown results run one bounded review and make notices visible here. Report missing config and exit. Do not delete host data, create schedules or send external messages.

Every 14 days, interval `{"type":"interval","everyMs":1209600000}`:

> Use the repository-local housekeeping skill with --review. Compare timestamped comparable telemetry, report growth and protected/unknown candidates, and name decisions needed. A healthy no-op is valid. Do not delete host data, create schedules or send external messages.

The daily task provides early warning. A fortnightly review alone cannot prevent a rapid disk-space incident. Tasks run only after a user enables them, and missed runs or sudden growth can still outrun the warning.
