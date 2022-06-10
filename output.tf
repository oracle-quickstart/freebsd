output "subscription" {
  value = data.oci_core_app_catalog_subscriptions.mp_image_subscription.*.app_catalog_subscriptions
}

output "freeBSD_instance_public_ips" {
  value = [oci_core_instance.ha-vms[0].*.public_ip]
}

output "freeBSD_instance_private_ips" {
  value = [oci_core_instance.ha-vms[0].*.private_ip]
}

output "instance_https_urls" {
  value = formatlist("https://%s", oci_core_instance.ha-vms.*.public_ip)
}

output "initial_instruction" {
value = <<EOT
1.  Open an SSH client.
2.  Use the following information to connect to the instance
username: freebsd
IP_Address: ${oci_core_instance.ha-vms.0.public_ip}
SSH Key
For example:
$ ssh –i id_rsa admin@${oci_core_instance.ha-vms.0.public_ip}
3.  For additional details follow the official documentation.
EOT
}
