# Works off the asumption that the PATH defined `gcloud` command
# is defined within the `/bin` folder of the Google Cloud
# SDK structure. And a sibling to that `/bin` folder
# is the completion files.

comp_file_name="completion.zsh.inc"
gcloud_sdk_path="$(which gcloud | xargs readlink -f | xargs dirname | xargs dirname)"

source "${gcloud_sdk_path}/${comp_file_name}"

unset comp_file_name gcloud_sdk_path

gssh() {
  host_at_project="${1}"
  : "${host_at_project:?requires providing a host machine name and project name in format of host@project[@zone]}"

  host="$(echo ${host_at_project} | cut -d@ -f1)"
  project="$(echo ${host_at_project} | cut -d@ -f2)"

  zone="$(echo ${host_at_project} | cut -d@ -f3)"
  zone="${zone:-${2}}"
  : "${zone:?requires providing a GCP zone, either as third segment of first argument or a second argument}"

  gcloud compute ssh --zone "${zone}" "${host}" --project "${project}"
}

gsshi() {
  host_at_project="${1}"
  : "${host_at_project:?requires providing a host machine name and project name in format of host@project[@zone]}"

  host="$(echo ${host_at_project} | cut -d@ -f1)"
  project="$(echo ${host_at_project} | cut -d@ -f2)"

  zone="$(echo ${host_at_project} | cut -d@ -f3)"
  zone="${zone:-${2}}"
  : "${zone:?requires providing a GCP zone, either as third segment of first argument or a second argument}"

  gcloud compute ssh --zone "${zone}" "${host}" --project "${project}" --internal-ip
}
