#!/usr/local/bin/perl
# Create, update or delete a template

require './status-lib.pl';
$access{'edit'} || &error($text{'tmpls_ecannot'});
&ReadParse();
&error_setup($text{'tmpl_err'});

# Get the template
if (!$in{'new'}) {
	$tmpl = &get_template($in{'id'});
	}
else {
	$tmpl = { };
	}

if ($in{'delete'}) {
	# Remove this template
	&error_setup($text{'tmpl_err2'});
	@users = grep { $_->{'tmpl'} eq $tmpl->{'id'} } &list_services();
	@users && &error(&text('tmpl_eusers',
			join(", ", map { "<i>$_->{'desc'}</i>" } @users)));
	&delete_template($tmpl);
	&webmin_log("delete", "template", $tmpl->{'desc'});
	}
else {
	# Validate and store inputs
	$in{'desc'} =~ /\S/ || &error($text{'tmpl_edesc'});
	$tmpl->{'desc'} = $in{'desc'};
	$in{'email'} =~ /\S/ || &error($text{'tmpl_eemail'});
	$tmpl->{'email'} = $in{'email'};
	if ($in{'sms_def'}) {
		delete($tmpl->{'sms'});
		}
	else {
		$in{'sms'} =~ /\S/ || &error($text{'tmpl_esms'});
		$tmpl->{'sms'} = $in{'sms'};
		}
	if ($in{'snmp_def'}) {
		delete($tmpl->{'snmp'});
		}
	else {
		$in{'snmp'} =~ /\S/ || &error($text{'tmpl_esnmp'});
		$tmpl->{'snmp'} = $in{'snmp'};
		}

	# Save or create
	&save_template($tmpl);
	&webmin_log($in{'new'} ? "create" : "modify", "template",
		    $tmpl->{'desc'});
	}
&redirect("list_tmpls.cgi");

