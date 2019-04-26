#!/bin/bash

function parse_input() {
  # jq reads from stdin so we don't have to set up any inputs, but let's validate the outputs
  eval "$(jq -r '@sh "export TF_PACKET_PC_HOST=\(.host) TF_PACKET_PC_SSH_KEY=\(.ssh_key)"')"
	if [[ -z "${TF_PACKET_PC_HOST}" ]]; then
		jq -n \
			--arg second_iface "" \
			'{"iface":$second_iface}'
		exit
	fi
}

function find_second_iface {
	export second_iface=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@${TF_PACKET_PC_HOST} grep bond-slaves /etc/network/interfaces | awk '{ print $3; }')
	if [[ -z "${second_iface}" ]]; then
		export second_iface=$(ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@${TF_PACKET_PC_HOST} grep auto /etc/network/interfaces.d/second | awk '{ print $2; }')
	fi
}

function produce_output {
	jq -n \
    --arg second_iface "${second_iface}" \
    '{"iface":$second_iface}'
}

parse_input
find_second_iface
produce_output
