#!/usr/local/bin/perl
# save_messages.cgi
# Save welcome and other messages

require './jabber-lib.pl';
&ReadParse();
&error_setup($text{'messages_err'});

$conf = &get_jabber_config();
$session = &find_by_tag("service", "id", "sessions", $conf);
$jsm = &find("jsm", $session);
$welcome = &find("welcome", $jsm);
$register = &find("register", $jsm);
$vcard = &find("vcard", $jsm);

# Validate and store inputs
&save_directive($welcome, "subject",
		[ [ "subject", [ { }, 0, $in{'wsubject'} ] ] ] );
&save_directive($welcome, "body",
		[ [ "body", [ { }, 0, $in{'wbody'} ] ] ] );
eval {
	$xml = new XML::Parser('Style' => 'Tree');
	$in{'vcard'} =~ s/\r//g;
	$vcxml = $xml->parse($in{'vcard'});
	};
$register->[1]->[0]->{'notify'} = $in{'rnotify'} ? 'yes' : 'no';
&save_directive($register, "instructions",
		[ [ "instructions", [ { }, 0, $in{'rinstr'} ] ] ] );
foreach $f (@register_fields) {
	if ($in{"rfield_$f"}) {
		&save_directive($register, $f, [ [ $f, [ { } ] ] ] );
		}
	else {
		&save_directive($register, $f);
		}
	}
&error(&text('messages_evcard', $@)) if ($@);
&error($text{'messages_etag'}) if (lc($vcxml->[0]) ne 'vcard');
&save_directive($jsm, [ $vcard ], [ $vcxml ]);
&save_directive($jsm, "vcard2jud",
		$in{'vcard2jud'} ? [ [ 'vcard2jud', [ { } ] ] ] : [ ] );

&save_jabber_config($conf);
&redirect("");

