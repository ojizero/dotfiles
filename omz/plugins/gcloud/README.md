# gcloud

`gcloud` completions along with some helper aliases.

## Functions

| Function | Behaviour                                                                                                                                                                                         |
| :------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `gssh`   | Allows sshing into a GCP VM provided a host, project, and zone using the `gcloud compute` command. Example: `gssh foo@bar baz` to execute `gcloud compute ssh --zone "baz" "foo" --project "bar". |
