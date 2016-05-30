#!/usr/local/bin/perl
# conf_forwarding.cgi
# Display global forwarding and transfer options
use strict;
use warnings;
# Globals
our (%access, %text);

require './bind8-lib.pl';
$access{'defaults'} || &error($text{'forwarding_ecannot'});
&ui_print_header(undef, $text{'forwarding_title'}, "",
		 undef, undef, undef, undef, &restart_links());

my $conf = &get_config();
my $options = &find("options", $conf);
my $mems = $options->{'members'};

# Start of the form
print &ui_form_start("save_forwarding.cgi", "post");
print &ui_table_start($text{'forwarding_header'}, "width=100%", 4);

print &forwarders_input($text{'forwarding_fwders'}, 'forwarders', $mems);

print &choice_input($text{'forwarding_fwd'}, 'forward', $mems,
		    $text{'yes'}, 'first', $text{'no'}, 'only',
		    $text{'default'}, undef);

print &opt_input($text{'forwarding_max'}, "max-transfer-time-in",
		 $mems, $text{'default'}, 4, $text{'forwarding_minutes'});

print &choice_input($text{'forwarding_format'}, 'transfer-format', $mems,
		    $text{'forwarding_one'}, 'one-answer',
		    $text{'forwarding_many'}, 'many-answers',
		    $text{'default'}, undef);

print &opt_input($text{'forwarding_in'}, "transfers-in",
		 $mems, $text{'default'}, 4);

print &opt_input($text{'forwarding_per_ns'}, "transfers-per-ns",
		 $mems, $text{'default'}, 4);

print &opt_input($text{'forwarding_out'}, "transfers-out",
		 $mems, $text{'default'}, 4);

print &ui_table_end();
print &ui_form_end([ [ undef, $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

