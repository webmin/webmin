#!/usr/local/bin/perl
# Create, update or delete a rule

require './tcpwrappers-lib.pl';
&ReadParse();
&error_setup($text{'save_errtitle'});
$type = $in{'allow'} ? 'allow' : 'deny';
$file = $config{'hosts_'.$type};
@rules = &list_rules($file);

if (!$in{'new'}) {
    ($rule) = grep { $_->{'id'} == $in{'id'} } @rules;
    $rule || &error($text{'edit_eid'});
}
        
&lock_file($file);
if ($in{'delete'}) {
    # Delete one rule
    &delete_rule($file, $rule);
    goto ALLDONE;
} else {
    # Check input
    &error($text{'save_eservice'}) if ($in{'service_custom'} && $in{'service_custom'} !~ /^[\w\d\s\-\/\.,]+$/);
    &error($text{'save_eservice'}) if ($in{'service_except_custom'} && $in{'service_except_custom'} !~ /^[\w\d\s\-\/\.,]+$/);

    &error($text{'save_ehost'}) if ($in{'host_text_def'} == 0 && $in{'host_text'} !~ /^[\w\d\s\-\/\@\.,]+$/);
    &error($text{'save_ehost'}) if ($in{'host_except'} && $in{'host_except'} !~ /^[\w\d\s\-\/\@\.,]+$/);

    for (my $i = 0; $i <= $in{'cmd_count'}; $i++) {
	&error($text{'save_ecmd'}) if ($in{'cmd_'.$i} && $in{'cmd_'.$i} !~ /^[\w\d\s\-\/\@\%\|\(\)\'\"\&\.,]+$/);
    }
}

# Build rule record
if ($in{'service_custom'}) {
    $service = $in{'service_custom'};
    if ($in{'service_except_custom'}) {
	$service .= " EXCEPT ".$in{'service_except_custom'};
    }
} else {
    # listed from (x)inetd
    $service = join(",", split /\0/, $in{'service'});
    if ($in{'service_except'}) {
	$service .= " EXCEPT ".join(",", split /\0/, $in{'service_except'});
    }
}

$host = $in{'host_text_def'} ? $in{'host_select'} : $in{'host_text'};
if ($in{'host_except'}) {
    $host .= " EXCEPT ".$in{'host_except'};
}

$cmd = '';
for (my $i = 0; $i <= $in{'cmd_count'}; $i++) {
    next unless ($in{'cmd_'.$i});
    $cmd .= $cmd ? " : " : '';
    $cmd .= $in{'cmd_directive_'.$i} ne 'none' ? $in{'cmd_directive_'.$i}.' ' : '';
    $cmd .= $in{'cmd_'.$i};
}

my %newrule = ( 'service' => $service,
		'host' => $host,
		'cmd' => $cmd
		);

# Save to file
if ($in{'new'}) {
    &create_rule($file, \%newrule);
} else {
    &modify_rule($file, $rule, \%newrule);
}

ALLDONE:
&unlock_file($file);
&webmin_log($in{'new'} ? "create" : $in{'delete'} ? "delete" : "modify", "rule", $rule->{'id'});
&redirect("index.cgi?type=$type");

