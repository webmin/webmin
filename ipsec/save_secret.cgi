#!/usr/local/bin/perl
# Create, update or delete a secret key

require './ipsec-lib.pl';
&ReadParse();
@secs = &list_secrets();
if ($in{'new'}) {
	$sec = { 'type' => $in{'type'} };
	}
else {
	$sec = $secs[$in{'idx'}];
	}

if ($in{'delete'}) {
	# Just kill this key
	@secs > 1 || &error($text{'secret_elast'});
	&lock_file($config{'secrets'});
	&delete_secret($sec);
	&unlock_file($config{'secrets'});
	&webmin_log("delete", "secret", undef, { 'name' => $sec->{'name'} });
	}
else {
	# Validate inputs
	&error_setup($text{'secret_err'});
	$in{'name_def'} || $in{'name'} =~ /\S/ ||
		&error($text{'secret_ename'});
	$oldname = $sec->{'name'};
	$sec->{'name'} = $in{'name_def'} ? "" : $in{'name'};
	if (lc($sec->{'type'}) eq 'psk') {
		$in{'pass'} || &error($text{'secret_epass'});
		$sec->{'value'} = "\"$in{'pass'}\"";
		}
	elsif (lc($sec->{'type'}) eq 'rsa') {
		$sec->{'value'} = "{\n";
		@rsa_in = map { $_ =~ /^rsa_(\S+)/ ? ( $1 ) : ( ) } keys(%in);
		foreach $p (&unique(@rsa_attribs, @rsa_in)) {
			$k = "rsa_$p";
			next if (!defined($in{$k}));
			$in{$k} =~ s/\s//g;
			$in{$k} =~ /\S/ || &error(&text('secret_ersa', $p));
			$sec->{'value'} .= "\t".$p.": ".$in{$k}."\n";
			}
		$sec->{'value'} .= "\t}";
		}

	# Update or create
	&lock_file($config{'secrets'});
	if ($in{'new'}) {
		&create_secret($sec);
		$logname = $sec->{'name'};
		}
	else {
		&modify_secret($sec);
		$logname = $oldname;
		}
	&unlock_file($config{'secrets'});
	&webmin_log($in{'new'} ? "create" : "modify", "secret", undef,
		    { 'name' => $logname });
	}
&redirect("list_secrets.cgi");

