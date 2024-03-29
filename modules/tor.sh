#!/bin/bash

function tor {
  check_missing_packages "tor" "curl"

  if { [ ! -d "/var/lib/tor/treehouses" ] || [ ! -f "/var/lib/tor/treehouses/hostname" ]; } && [ "$1" != "start" ] && [ "$1" != "add" ]; then
    echo "Error: the tor service has not been configured."
    echo "Run '$(basename "$0") tor start' to configure it."
    echo "Or '$(basename "$0") add [localPort]' to add a port and be able to use the service"
    exit
  fi

  if [ -z "$1" ]; then
    cat "/var/lib/tor/treehouses/hostname"
    exit
  fi

  if [ "$1" = "list" ]; then
    echo "external <=> local"
    grep -Poi "^HiddenServicePort \\K(.*) 127.0.0.1:(.*)\\b" /etc/tor/torrc | tac | sed -r 's/(.*?)127.0.0.1:(.*?)/\2 <=> \1/g'
  elif [ "$1" = "add" ]; then
    if ! grep -Pq "^HiddenServiceDir .*" "/etc/tor/torrc"; then
      echo "HiddenServiceDir /var/lib/tor/treehouses" >> /etc/tor/torrc
    fi

    local_port="$2"
    external_port="$3"

    if [ -z "$local_port" ]; then
      echo "Error: you must specify a local port"
      exit 
    fi

    if [ -z "$external_port" ]; then
      external_port="$local_port"
    fi

    existing_port=$(grep -Poi "^HiddenServicePort $local_port .*" /etc/tor/torrc)
    if [ ! -z "$existing_port" ]; then
      sed -i "s/$existing_port/HiddenServicePort $local_port 127.0.0.1:$external_port/g" /etc/tor/torrc
    else
      echo "HiddenServicePort $local_port 127.0.0.1:$external_port" >> /etc/tor/torrc
    fi

    restart_service tor
    echo "Success: the port has been added"
  elif [ "$1" = "stop" ]; then
    stop_service tor
    echo "Success: the tor service has been stopped"
  elif [ "$1" = "start" ]; then
    if [ ! -d "/var/lib/tor/treehouses" ]; then
      mkdir "/var/lib/tor/treehouses"
      chown debian-tor:debian-tor /var/lib/tor/treehouses
      chmod 700 /var/lib/tor/treehouses
    fi

    if ! grep -Pq "^HiddenServiceDir .*" "/etc/tor/torrc"; then
      echo "HiddenServiceDir /var/lib/tor/treehouses" >> /etc/tor/torrc
    fi

    start_service tor
    echo "Success: the tor service has been started"
  elif [ "$1" = "destroy" ]; then
    stop_service tor
    echo > /etc/tor/torrc
    rm -rf /var/lib/tor/treehouses

    echo "Success: the tor service has been destroyed"
  elif [ "$1" = "notice" ]; then
    option="$2"
    if [ "$option" = "on" ]; then
      cp "$TEMPLATES/network/tor_report.sh" /etc/tor_report.sh
      if [ ! -f "/etc/cron.d/tor_report" ]; then
        echo "*/1 * * * * root if [ -d \"/var/lib/tor/treehouses\" ]; then /etc/tor_report.sh; fi" > /etc/cron.d/tor_report
      fi
      if [ ! -f "/etc/tor_report_channels.txt" ]; then
        echo "https://api.gitter.im/v1/rooms/5ba5af3cd73408ce4fa8fcfb/chatMessages" >> /etc/tor_report_channels.txt
      fi
      echo "OK."
    elif [ "$option" = "add" ]; then
      value="$3"
      if [ -z "$value" ]; then
        echo "Error: You must specify a channel URL"
        exit 1
      fi

      echo "$value" >> /etc/tor_report_channels.txt
      echo "OK."
    elif [ "$option" = "delete" ]; then
      value="$3"
      if [ -z "$value" ]; then
        echo "Error: You must specify a channel URL"
        exit 1
      fi

      value=$(echo $value | sed 's/\//\\\//g')
      sed -i "/^$value/d" /etc/tor_report_channels.txt
      echo "OK."
    elif [ "$option" = "list" ]; then
      if [ -f "/etc/tor_report_channels.txt" ]; then
        cat /etc/tor_report_channels.txt
      else
        echo "No channels found. No message send"
      fi
    elif [ "$option" = "off" ]; then
      rm -rf /etc/tor_report.sh /etc/cron.d/tor_report /etc/tor_report_channels.txt || true
      echo "OK."
    elif [ -z "$option" ]; then
      if [ -f "/etc/cron.d/tor_report" ]; then
        status="on"
      else
        status="off"
      fi
      echo "Status: $status"
    else
      echo "Error: only 'on' and 'off' options are supported."
    fi
  elif [ "$1" = "status" ]; then
    systemctl is-active tor
  else
    echo "Error: only 'list', 'add', 'start', 'stop', 'status', 'notice' and 'destroy' options are supported."
  fi
}

function tor_help {

  echo ""
  echo "Usage: $(basename "$0") tor"
  echo ""
  echo "Setups the tor service on the rpi"
  echo ""
  echo "Examples:"
  echo "  $(basename "$0") tor"
  echo "      Outputs the hostname of the tor service"
  echo ""
  echo "  $(basename "$0") tor list"
  echo "      Outputs the ports that are exposed on the tor network"
  echo "      Example:"
  echo "        external <=> local"
  echo "        22       <=> 22"
  echo "        80       <=> 80"
  echo "      the port 22 is open and routing the traffic of the local port 22,"
  echo "      the port 80 is open and routing the traffic of the local port 80"
  echo ""
  echo "  $(basename "$0") tor add <localPort> [externalPort]"
  echo "      Adds the desired local port to be accesible from the tor network"
  echo ""
  echo "  $(basename "$0") tor start"
  echo "      Setups and starts the tor service"
  echo ""
  echo "  $(basename "$0") tor stop"
  echo "      Stops the tor service"
  echo ""
  echo "  $(basename "$0") tor destroy"
  echo "      Stops and resets the tor configuration"
  echo ""
  echo "  $(basename "$0") tor notice <on|off|add|delete|list> [api_url]"
  echo "      Enables or disables the propagation of the tor address/ports to gitter"
  echo ""
  echo "  $(basename "$0") tor status"
  echo "      Outputs the status of the tor service"
  echo ""
}
