#!/usr/local/bin/perl
# k8s-lib.pl
# Kubernetes management library

use strict;
use warnings;

require '../web-lib.pl';
our (%text, %config, $module_name);

sub validate_k8s_name {
    my ($name) = @_;
    return 0 unless defined $name && length($name) > 0;
    return 0 if length($name) > 253;
    return 0 if $name =~ /[^a-zA-Z0-9._-]/;
    return 0 if $name =~ /^\./ || $name =~ /\.$/;
    return 1;
}

sub validate_namespace {
    my ($namespace) = @_;
    return 0 unless defined $namespace && length($namespace) > 0;
    return 0 if length($namespace) > 63;
    return 0 if $namespace =~ /[^a-z0-9.-]/;
    return 0 if $namespace =~ /^-/ || $namespace =~ /-$/;
    return 1;
}

sub validate_replicas {
    my ($replicas) = @_;
    return 0 unless defined $replicas;
    return 0 unless $replicas =~ /^\d+$/;
    return 0 if $replicas < 0 || $replicas > 1000;
    return 1;
}

sub validate_context {
    my ($context) = @_;
    return 0 unless defined $context && length($context) > 0;
    return 0 if length($context) > 253;
    return 0 if $context =~ /[^a-zA-Z0-9._-]/;
    return 1;
}

sub sanitize_input {
    my ($input) = @_;
    return '' unless defined $input;
    $input =~ s/[;&|`'"\(\)\[\]\{\}\$\<\>\!\*]//g;
    $input =~ s/\s+/ /g;
    $input =~ s/^\s+|\s+$//g;
    return $input;
}

sub escape_html {
    my ($text) = @_;
    return '' unless defined $text;
    $text =~ s/&/&amp;/g;
    $text =~ s/</&lt;/g;
    $text =~ s/>/&gt;/g;
    $text =~ s/"/&quot;/g;
    $text =~ s/'/&#39;/g;
    return $text;
}

sub get_kubectl_cmd {
    my $cmd = $config{'kubectl_cmd'} || '/usr/bin/kubectl';
    return &sanitize_input($cmd);
}

sub get_kubeconfig_path {
    my $path = $config{'kubeconfig_path'} || $ENV{'HOME'}.'/.kube/config';
    $path =~ s/[^a-zA-Z0-9\/\._-]//g;
    return $path;
}

sub get_kubectl_args {
    my $args = "";
    my $kubeconfig = &get_kubeconfig_path();
    $args .= " --kubeconfig=". &shell_quote($kubeconfig) if (-f $kubeconfig);
    return $args;
}

sub shell_quote {
    my ($str) = @_;
    return "''" unless defined $str && length($str) > 0;
    $str =~ s/'/'\\''/g;
    return "'$str'";
}

sub list_pods {
    my ($namespace) = @_;
    my @pods;

    if (defined $namespace && !&validate_namespace($namespace)) {
        &error_log("Invalid namespace: ".&escape_html($namespace));
        return ();
    }

    my $cmd = &get_kubectl_cmd().&get_kubectl_args()." get pods";
    $cmd .= " -n ".&shell_quote($namespace) if ($namespace);
    $cmd .= " -o json";

    my ($out, $err) = &safe_backquote($cmd);
    return () if defined $err;

    eval "use JSON::PP";
    if (!$@) {
        my $json = JSON::PP->new;
        eval {
            my $data = $json->decode($out);
            foreach my $item (@{$data->{'items'}}) {
                my $name = &escape_html($item->{'metadata'}->{'name'} || '');
                my $ns = &escape_html($item->{'metadata'}->{'namespace'} || '');
                my $status = &escape_html($item->{'status'}->{'phase'} || '');
                my $node = &escape_html($item->{'spec'}->{'nodeName'} || '');
                my $image = &escape_html($item->{'spec'}->{'containers'}->[0]->{'image'} || '');
                my $age = &escape_html($item->{'metadata'}->{'creationTimestamp'} || '');

                push(@pods, {
                    'name' => $name,
                    'namespace' => $ns,
                    'status' => $status,
                    'node' => $node,
                    'restarts' => defined $item->{'status'}->{'containerStatuses'}->[0]->{'restartCount'} 
                        ? int($item->{'status'}->{'containerStatuses'}->[0]->{'restartCount'}) : 0,
                    'image' => $image,
                    'age' => $age,
                    'labels' => $item->{'metadata'}->{'labels'},
                });
            }
        };
        if ($@) {
            &error_log("JSON parsing error: $@");
        }
    }

    return @pods;
}

sub list_services {
    my ($namespace) = @_;
    my @services;

    if (defined $namespace && !&validate_namespace($namespace)) {
        &error_log("Invalid namespace: ".&escape_html($namespace));
        return ();
    }

    my $cmd = &get_kubectl_cmd().&get_kubectl_args()." get services";
    $cmd .= " -n ".&shell_quote($namespace) if ($namespace);
    $cmd .= " -o json";

    my ($out, $err) = &safe_backquote($cmd);
    return () if defined $err;

    eval "use JSON::PP";
    if (!$@) {
        my $json = JSON::PP->new;
        eval {
            my $data = $json->decode($out);
            foreach my $item (@{$data->{'items'}}) {
                my $type = &escape_html($item->{'spec'}->{'type'} || 'ClusterIP');
                my $cluster_ip = &escape_html($item->{'spec'}->{'clusterIP'} || '-');
                my @ports;
                foreach my $port (@{$item->{'spec'}->{'ports'}}) {
                    my $p = $port->{'port'};
                    $p .= ":".&escape_html($port->{'targetPort'}) if defined $port->{'targetPort'};
                    push(@ports, $p);
                }
                push(@services, {
                    'name' => &escape_html($item->{'metadata'}->{'name'} || ''),
                    'namespace' => &escape_html($item->{'metadata'}->{'namespace'} || ''),
                    'type' => $type,
                    'cluster_ip' => $cluster_ip,
                    'ports' => join(', ', @ports),
                    'age' => &escape_html($item->{'metadata'}->{'creationTimestamp'} || ''),
                    'labels' => $item->{'metadata'}->{'labels'},
                });
            }
        };
        if ($@) {
            &error_log("JSON parsing error: $@");
        }
    }

    return @services;
}

sub list_deployments {
    my ($namespace) = @_;
    my @deployments;

    if (defined $namespace && !&validate_namespace($namespace)) {
        &error_log("Invalid namespace: ".&escape_html($namespace));
        return ();
    }

    my $cmd = &get_kubectl_cmd().&get_kubectl_args()." get deployments";
    $cmd .= " -n ".&shell_quote($namespace) if ($namespace);
    $cmd .= " -o json";

    my ($out, $err) = &safe_backquote($cmd);
    return () if defined $err;

    eval "use JSON::PP";
    if (!$@) {
        my $json = JSON::PP->new;
        eval {
            my $data = $json->decode($out);
            foreach my $item (@{$data->{'items'}}) {
                push(@deployments, {
                    'name' => &escape_html($item->{'metadata'}->{'name'} || ''),
                    'namespace' => &escape_html($item->{'metadata'}->{'namespace'} || ''),
                    'replicas' => defined $item->{'spec'}->{'replicas'} ? int($item->{'spec'}->{'replicas'}) : 1,
                    'available' => defined $item->{'status'}->{'availableReplicas'} ? int($item->{'status'}->{'availableReplicas'}) : 0,
                    'ready' => defined $item->{'status'}->{'readyReplicas'} ? int($item->{'status'}->{'readyReplicas'}) : 0,
                    'updated' => defined $item->{'status'}->{'updatedReplicas'} ? int($item->{'status'}->{'updatedReplicas'}) : 0,
                    'image' => &escape_html($item->{'spec'}->{'template'}->{'spec'}->{'containers'}->[0]->{'image'} || ''),
                    'age' => &escape_html($item->{'metadata'}->{'creationTimestamp'} || ''),
                    'labels' => $item->{'metadata'}->{'labels'},
                });
            }
        };
        if ($@) {
            &error_log("JSON parsing error: $@");
        }
    }

    return @deployments;
}

sub list_namespaces {
    my @namespaces;
    my $cmd = &get_kubectl_cmd().&get_kubectl_args()." get namespaces -o json";

    my ($out, $err) = &safe_backquote($cmd);
    return () if defined $err;

    eval "use JSON::PP";
    if (!$@) {
        my $json = JSON::PP->new;
        eval {
            my $data = $json->decode($out);
            foreach my $item (@{$data->{'items'}}) {
                push(@namespaces, {
                    'name' => &escape_html($item->{'metadata'}->{'name'} || ''),
                    'status' => &escape_html($item->{'status'}->{'phase'} || ''),
                    'age' => &escape_html($item->{'metadata'}->{'creationTimestamp'} || ''),
                });
            }
        };
        if ($@) {
            &error_log("JSON parsing error: $@");
        }
    }

    return @namespaces;
}

sub list_nodes {
    my @nodes;
    my $cmd = &get_kubectl_cmd().&get_kubectl_args()." get nodes -o json";

    my ($out, $err) = &safe_backquote($cmd);
    return () if defined $err;

    eval "use JSON::PP";
    if (!$@) {
        my $json = JSON::PP->new;
        eval {
            my $data = $json->decode($out);
            foreach my $item (@{$data->{'items'}}) {
                my @conditions;
                foreach my $cond (@{$item->{'status'}->{'conditions'}}) {
                    push(@conditions, &escape_html($cond->{'type'}).': '.($cond->{'status'} eq 'True' ? 'Ready' : 'NotReady'));
                }
                my @roles;
                foreach my $key (keys %{$item->{'metadata'}->{'labels'}}) {
                    push(@roles, &escape_html($key)) if $key ne 'node';
                }
                push(@nodes, {
                    'name' => &escape_html($item->{'metadata'}->{'name'} || ''),
                    'status' => join(', ', @conditions),
                    'roles' => join(', ', @roles),
                    'version' => &escape_html($item->{'status'}->{'nodeInfo'}->{'kubeletVersion'} || ''),
                    'os' => &escape_html($item->{'status'}->{'nodeInfo'}->{'operatingSystem'} || ''),
                    'kernel' => &escape_html($item->{'status'}->{'nodeInfo'}->{'kernelVersion'} || ''),
                    'age' => &escape_html($item->{'metadata'}->{'creationTimestamp'} || ''),
                });
            }
        };
        if ($@) {
            &error_log("JSON parsing error: $@");
        }
    }

    return @nodes;
}

sub list_configmaps {
    my ($namespace) = @_;
    my @configmaps;

    if (defined $namespace && !&validate_namespace($namespace)) {
        &error_log("Invalid namespace: ".&escape_html($namespace));
        return ();
    }

    my $cmd = &get_kubectl_cmd().&get_kubectl_args()." get configmaps";
    $cmd .= " -n ".&shell_quote($namespace) if ($namespace);
    $cmd .= " -o json";

    my ($out, $err) = &safe_backquote($cmd);
    return () if defined $err;

    eval "use JSON::PP";
    if (!$@) {
        my $json = JSON::PP->new;
        eval {
            my $data = $json->decode($out);
            foreach my $item (@{$data->{'items'}}) {
                my $data_keys = $item->{'data'} ? scalar(keys %{$item->{'data'}}) : 0;
                push(@configmaps, {
                    'name' => &escape_html($item->{'metadata'}->{'name'} || ''),
                    'namespace' => &escape_html($item->{'metadata'}->{'namespace'} || ''),
                    'data_keys' => $data_keys,
                    'age' => &escape_html($item->{'metadata'}->{'creationTimestamp'} || ''),
                });
            }
        };
        if ($@) {
            &error_log("JSON parsing error: $@");
        }
    }

    return @configmaps;
}

sub list_secrets {
    my ($namespace) = @_;
    my @secrets;

    if (defined $namespace && !&validate_namespace($namespace)) {
        &error_log("Invalid namespace: ".&escape_html($namespace));
        return ();
    }

    my $cmd = &get_kubectl_cmd().&get_kubectl_args()." get secrets";
    $cmd .= " -n ".&shell_quote($namespace) if ($namespace);
    $cmd .= " -o json";

    my ($out, $err) = &safe_backquote($cmd);
    return () if defined $err;

    eval "use JSON::PP";
    if (!$@) {
        my $json = JSON::PP->new;
        eval {
            my $data = $json->decode($out);
            foreach my $item (@{$data->{'items'}}) {
                my $type = &escape_html($item->{'type'} || 'Opaque');
                push(@secrets, {
                    'name' => &escape_html($item->{'metadata'}->{'name'} || ''),
                    'namespace' => &escape_html($item->{'metadata'}->{'namespace'} || ''),
                    'type' => $type,
                    'age' => &escape_html($item->{'metadata'}->{'creationTimestamp'} || ''),
                });
            }
        };
        if ($@) {
            &error_log("JSON parsing error: $@");
        }
    }

    return @secrets;
}

sub get_pod_details {
    my ($name, $namespace) = @_;
    $namespace ||= 'default';

    unless (&validate_k8s_name($name)) {
        &error_log("Invalid pod name: ".&escape_html($name));
        return (undef, "Invalid pod name");
    }

    unless (&validate_namespace($namespace)) {
        &error_log("Invalid namespace: ".&escape_html($namespace));
        return (undef, "Invalid namespace");
    }

    my $cmd = &get_kubectl_cmd().&get_kubectl_args()." get pod ".&shell_quote($name)." -n ".&shell_quote($namespace)." -o json";

    my ($out, $err) = &safe_backquote($cmd);
    return (undef, "Failed to get pod details") if defined $err;

    eval "use JSON::PP";
    if (!$@) {
        my $json = JSON::PP->new;
        eval {
            my $data = $json->decode($out);
            return ($data, undef);
        };
        if ($@) {
            &error_log("JSON parsing error: $@");
        }
    }

    return (undef, "Failed to parse pod details");
}

sub get_pod_logs {
    my ($name, $namespace, $lines) = @_;
    $namespace ||= 'default';
    $lines ||= 100;

    unless (&validate_k8s_name($name)) {
        &error_log("Invalid pod name: ".&escape_html($name));
        return ("", "Invalid pod name");
    }

    unless (&validate_namespace($namespace)) {
        &error_log("Invalid namespace: ".&escape_html($namespace));
        return ("", "Invalid namespace");
    }

    unless ($lines =~ /^\d+$/ && $lines > 0 && $lines <= 10000) {
        &error_log("Invalid lines parameter: ".&escape_html($lines));
        return ("", "Invalid lines parameter");
    }

    my $cmd = &get_kubectl_cmd().&get_kubectl_args()." logs ".&shell_quote($name)." -n ".&shell_quote($namespace)." --tail=$lines";

    my ($out, $err) = &safe_backquote($cmd);
    return ($out, defined $err ? "Failed to get logs" : undef);
}

sub pod_action {
    my ($name, $namespace, $action) = @_;
    $namespace ||= 'default';

    unless (&validate_k8s_name($name)) {
        &error_log("Invalid pod name: ".&escape_html($name));
        return (0, "Invalid pod name");
    }

    unless (&validate_namespace($namespace)) {
        &error_log("Invalid namespace: ".&escape_html($namespace));
        return (0, "Invalid namespace");
    }

    unless ($action =~ /^(delete|describe)$/) {
        &error_log("Invalid action: ".&escape_html($action));
        return (0, "Unknown action: ".&escape_html($action));
    }

    my $cmd;
    if ($action eq 'delete') {
        $cmd = &get_kubectl_cmd().&get_kubectl_args()." delete pod ".&shell_quote($name)." -n ".&shell_quote($namespace);
    }
    elsif ($action eq 'describe') {
        $cmd = &get_kubectl_cmd().&get_kubectl_args()." describe pod ".&shell_quote($name)." -n ".&shell_quote($namespace);
    }

    my ($out, $err) = &safe_backquote($cmd);
    return (defined $err ? 0 : 1, $out);
}

sub scale_deployment {
    my ($name, $namespace, $replicas) = @_;
    $namespace ||= 'default';

    unless (&validate_k8s_name($name)) {
        &error_log("Invalid deployment name: ".&escape_html($name));
        return (0, "Invalid deployment name");
    }

    unless (&validate_namespace($namespace)) {
        &error_log("Invalid namespace: ".&escape_html($namespace));
        return (0, "Invalid namespace");
    }

    unless (&validate_replicas($replicas)) {
        &error_log("Invalid replicas count: ".&escape_html($replicas));
        return (0, "Invalid replicas count");
    }

    my $cmd = &get_kubectl_cmd().&get_kubectl_args()." scale deployment ".&shell_quote($name)." -n ".&shell_quote($namespace)." --replicas=$replicas";

    my ($out, $err) = &safe_backquote($cmd);
    return (defined $err ? 0 : 1, $out);
}

sub delete_deployment {
    my ($name, $namespace) = @_;
    $namespace ||= 'default';

    unless (&validate_k8s_name($name)) {
        &error_log("Invalid deployment name: ".&escape_html($name));
        return (0, "Invalid deployment name");
    }

    unless (&validate_namespace($namespace)) {
        &error_log("Invalid namespace: ".&escape_html($namespace));
        return (0, "Invalid namespace");
    }

    my $cmd = &get_kubectl_cmd().&get_kubectl_args()." delete deployment ".&shell_quote($name)." -n ".&shell_quote($namespace);

    my ($out, $err) = &safe_backquote($cmd);
    return (defined $err ? 0 : 1, $out);
}

sub delete_service {
    my ($name, $namespace) = @_;
    $namespace ||= 'default';

    unless (&validate_k8s_name($name)) {
        &error_log("Invalid service name: ".&escape_html($name));
        return (0, "Invalid service name");
    }

    unless (&validate_namespace($namespace)) {
        &error_log("Invalid namespace: ".&escape_html($namespace));
        return (0, "Invalid namespace");
    }

    my $cmd = &get_kubectl_cmd().&get_kubectl_args()." delete service ".&shell_quote($name)." -n ".&shell_quote($namespace);

    my ($out, $err) = &safe_backquote($cmd);
    return (defined $err ? 0 : 1, $out);
}

sub get_k8s_version {
    my $cmd = &get_kubectl_cmd().&get_kubectl_args()." version --short";
    my ($out, $err) = &safe_backquote($cmd);
    return defined $err ? "Unknown" : &escape_html(chomp($out));
}

sub get_k8s_contexts {
    my @contexts;
    my $cmd = &get_kubectl_cmd().&get_kubectl_args()." config get-contexts -o json";

    my ($out, $err) = &safe_backquote($cmd);
    return () if defined $err;

    eval "use JSON::PP";
    if (!$@) {
        my $json = JSON::PP->new;
        eval {
            my $data = $json->decode($out);
            foreach my $item (@{$data->{'contexts'}}) {
                push(@contexts, {
                    'name' => &escape_html($item->{'name'} || ''),
                    'cluster' => &escape_html($item->{'context'}->{'cluster'} || ''),
                    'user' => &escape_html($item->{'context'}->{'user'} || ''),
                    'namespace' => &escape_html($item->{'context'}->{'namespace'} || ''),
                });
            }
        };
        if ($@) {
            &error_log("JSON parsing error: $@");
        }
    }

    return @contexts;
}

sub get_current_context {
    my $cmd = &get_kubectl_cmd().&get_kubectl_args()." config current-context";
    my ($out, $err) = &safe_backquote($cmd);
    return defined $err ? "" : &escape_html(chomp($out));
}

sub use_context {
    my ($context) = @_;

    unless (&validate_context($context)) {
        &error_log("Invalid context name: ".&escape_html($context));
        return (0, "Invalid context name");
    }

    my $cmd = &get_kubectl_cmd().&get_kubectl_args()." config use-context ".&shell_quote($context);

    my ($out, $err) = &safe_backquote($cmd);
    return (defined $err ? 0 : 1, $out);
}

sub safe_backquote {
    my ($cmd) = @_;

    &error_log("Executing command: ".&escape_html($cmd));

    my $out = &backquote_command($cmd);
    my $exit = $?;

    if ($exit != 0) {
        &error_log("Command failed with exit code $exit");
        return (undef, "Command execution failed");
    }

    return ($out, undef);
}

sub error_log {
    my ($msg) = @_;
    open(LOG, ">>/var/log/webmin/k8s-error.log") || return;
    print LOG localtime()." - $msg\n";
    close(LOG);
}

1;