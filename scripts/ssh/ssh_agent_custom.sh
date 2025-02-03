#!/bin/bash


ssh_agent_pids=$(pgrep -u "$USER" ssh-agent)
tmp_ssh_vars_file="$HOME/.tmp/ssh_vars"

# tmp_ssh_vars_file contents:
# SSH_AUTH_SOCK=/tmp/ssh-sLiFExgLuGjb/agent.3087; export SSH_AUTH_SOCK;
# SSH_AGENT_PID=3088; export SSH_AGENT_PID;
# echo Agent pid 3088;


if [ -z "$ssh_agent_pids" ]; then
	echo 'Launch ssh agent'
	ssh-agent > "$tmp_ssh_vars_file"
else
	if [ -f "$tmp_ssh_vars_file" ]; then
		agent_pid_found=0
		parse_tmp1=$(grep SSH_AGENT_PID "$tmp_ssh_vars_file")
		parse_tmp2=${parse_tmp1%%;*}
		agent_pid_from_file=${parse_tmp2#*=}
		for pid in $ssh_agent_pids; do
			if [ "$agent_pid_from_file" = "$pid" ]; then
				agent_pid_found=1
			fi
		done
		if [ "$agent_pid_found" = "0" ]; then
			echo "Agent pid '$agent_pid_from_file' not found - deleting file '$tmp_ssh_vars_file'"
			rm -f "$tmp_ssh_vars_file"
		fi
	fi
fi

exit 0

