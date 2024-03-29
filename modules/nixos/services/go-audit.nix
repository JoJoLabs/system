{ config, pkgs, lib, ... }: 
with lib;
{
  # options.security.go-audit.enable = mkEnableOption (lib.mdDoc "the Linux go-audit daemon");
  environment.systemPackages = with pkgs; [
    go-audit
    audit
  ];

  environment.etc = {
    # Creates /etc/go-audit.yaml
    "go-audit.yaml" = {
      text = ''
        # Configure socket buffers, leave unset to use the system defaults
        # Values will be doubled by the kernel
        # It is recommended you do not set any of these values unless you really need to
        socket_buffer:
          # Default is net.core.rmem_default (/proc/sys/net/core/rmem_default)
          # Maximum max is net.core.rmem_max (/proc/sys/net/core/rmem_max)
          receive: 16384

        events:
          # Minimum event type to capture, default 1300
          min: 1300
          # Maximum event type to capture, default 1399
          max: 1399

        # Configure message sequence tracking
        message_tracking:
          # Track messages and identify if we missed any, default true
          enabled: true

          # Log out of orderness, these messages typically signify an overloading system, default false
          log_out_of_order: false

          # Maximum out of orderness before a missed sequence is presumed dropped, default 500
          max_out_of_order: 500

        # Configure where to output audit events
        # Only 1 output can be active at a given time
        output:
          # Writes to stdout
          # All program status logging will be moved to stderr
          stdout:
            enabled: false

            # Total number of attempts to write a line before considering giving up
            # If a write fails go-audit will sleep for 1 second before retrying
            # Default is 3
            # attempts: 2

          # Appends logs to a file
          file:
            enabled: true
            attempts: 2

            # Path of the file to write lines to
            # The actual file will be created if it is missing but make sure the parent directory exists
            path: /var/log/go-audit/go-audit.log

            # Octal file mode for the log file, make sure to always have a leading 0
            mode: 0600

            # User and group that should own the log file
            user: root
            group: root

        # Configure logging, only stdout and stderr are used.
        log:
          # Gives you a bit of control over log line prefixes. Default is 0 - nothing.
          # To get the `filename:lineno` you would set this to 16
          #
          # Ldate         = 1  // the date in the local time zone: 2009/01/23
          # Ltime         = 2  // the time in the local time zone: 01:23:23
          # Lmicroseconds = 4  // microsecond resolution: 01:23:23.123123.  assumes Ltime.
          # Llongfile     = 8  // full file name and line number: /a/b/c/d.go:23
          # Lshortfile    = 16 // final file name element and line number: d.go:23. overrides Llongfile
          # LUTC          = 32 // if Ldate or Ltime is set, use UTC rather than the local time zone
          #
          # See also: https://golang.org/pkg/log/#pkg-constants
          flags: 2

        rules:
          # Watch all 64 bit program executions
          # - -a exit,always -F arch=b64 -S execve
          # Watch all 32 bit program executions
          # - -a exit,always -F arch=b32 -S execve
          # Watch kubernete lib folder
          - -a exit,always -F dir=/var/lib/kubernetes -p wa -F key=kubernetes_lib
          # Enable kernel auditing (required if not done via the "audit" kernel boot parameter)
          # You can also use this to lock the rules. Locking requires a reboot to modify the ruleset.
          # This should be the last rule in the chain.
          - -e 1

        # If kaudit filtering isn't powerful enough you can use the following filter mechanism
        filters:
          # Each filter consists of exactly 3 parts
          - syscall: 49 # The syscall id of the message group (a single log line from go-audit), to test against the regex
            message_type: 1306 # The message type identifier containing the data to test against the regex
            regex: saddr=(10..|0A..) # The regex to test against the message specific message types data

        extras:
          # Fetch extra fields for containers:
          # - containers.id
          # - containers.image (requires docker)
          # - containers.name (from kubernetes, if docker enabled)
          # - containers.pod_uid (from kubernetes, if docker enabled)
          # - containers.pod_name (from kubernetes, if available)
          # - containers.pod_namespace (from kubernetes, if available)
          #
          # The values listed below are the defaults, you can specify only the ones
          # you need to change
          containers:
            enabled: true

            # if enabled, make requests to the local containerd daemon for extra container details
            containerd: true
            containerd_sock: /run/containerd/containerd.sock
            containerd_namespace: k8s.io

            # number of pid -> container_id mappings to cache (0 means disable cache)
            pid_cache: 0
            # number of container_id -> containerd_details to cache (0 means disable cache)
            containerd_cache: 0
      '';

      # The UNIX file mode bits
      mode = "0440";
    };
  };

  systemd.services.go-audit = {
    description = "go-audit service";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    path = with pkgs; [
      audit
    ];
    serviceConfig = {
      ExecStart = "${pkgs.go-audit}/bin/go-audit -config /etc/go-audit.yaml";
      Type = "simple";
    };
  };

}