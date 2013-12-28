#!/usr/bin/perl
# list_rules.cgi
# Display a list of all active rules
require './itsecur-lib.pl';

&can_use_error("rules");
&header($text{'rules_title'}, "",
	undef, undef, undef, undef, &apply_button());
print "<hr>\n";


# 				0-No.	1-Source,2-Destination,	3-Services,	4-Time,	5-Action,	6-Enabled,	7-Comment 8-move
my @CW=(	"5%",	"15%",	"15%",			"20%",		"5%",		"10%",			"5%",			"10%", "2%");
my $C_drop="#FFCCcc";
my $C_reject="#FFDDAA";
my $C_accept="";
my $C_disabled="#FF3333";
my $C_separator="#ffffcc";

my $Row_Color="";

my @rules = &list_rules();
my @servs = &list_services();
my $edit = &can_edit("rules");
my $times = &supports_time() && &list_times() > 0;
my $rules_cnt = scalar(@rules);
my @links;
if ( $rules_cnt > 1 ) {
    push(@links, &select_all_link("r"));
    push(@links, &select_invert_link("r"));
}
if ($edit) {
    push(@links, &ui_link("edit_rule.cgi?new=1", $text{'rules_add'}) );
    push(@links, &ui_link("edit_sep.cgi?new=1", $text{'rules_sadd'}) );
}

if (@rules) {
	if ($edit) {
	    print &ui_links_row(\@links);
		print "<br>\n";
        print &ui_form_start("enable_rules.cgi", "post");
		}

    my @cols_text = ( "rule_num", "rule_source", "rule_dest",
                        "rules_service", "rule_time",
                        "rule_action", "rule_enabled",
                        "rules_desc", "rules_move" );
    my @cols_header;
    my @cols_header_width;
    my $cols = 0;
    foreach my $cc (@cols_text) {
        if ( $cc eq 'rule_time' && !$times ) {
            $cols++;
            next;
        }
        if ( $cc eq 'rules_desc' && !$config{'show_desc'} ) {
            $cols++;
            next; 
        }
        if ( $cc eq 'rules_move' && $rules_cnt <= 1 ) {
            $cols++;
            next;
        }
        push(@cols_header, $text{$cc});
        push(@cols_header_width, "width='".$CW[$cols]."'");
        $cols++;
    }
    print &ui_columns_start(\@cols_header, "100", undef, \@cols_header_width);

	foreach my $r (@rules) {
		if ($r->{'sep'}){
				$Row_Color="bgcolor=\"$C_separator\" ";				
		} elsif (!$r->{'enabled'}){
				$Row_Color="bgcolor=\"$C_disabled\" ";
		} elsif ( $r->{'action'} eq "drop" ){
				$Row_Color="bgcolor=\"$C_drop\" ";
		} elsif ( $r->{'action'} eq "reject" ){
				$Row_Color="bgcolor=\"$C_reject\" ";				
		} else {
			   $Row_Color=""; 
		}

		if ($r->{'sep'}) {
			# Actually a separator - just show it's description
            print &ui_columns_row([ &ui_link("edit_sep.cgi?idx=".$r->{'index'},
                                $r->{'desc'}, undef, "style='font-weight:bold;'") ],
                                [ "colspan='".$cols."' ".$Row_Color ] );
			}
		else {
			# Show full rule details			
            my @cols_row;
            my @cols_row_tag;
            my $link = &ui_link("edit_rule.cgi?idx=".$r->{'index'}, $r->{'num'});
            push(@cols_row, ( $edit ? &ui_checkbox("r", $r->{'index'}, "&nbsp;").$link : $link ) );
            push(@cols_row, &group_names_link($r->{'source'}, 'rules') );
            push(@cols_row, &group_names_link($r->{'dest'}, 'rules', ( &allow_action($r) ? 'dest' : undef) ) );
            push(@cols_row, &protocol_names($r->{'service'},\@servs) );
            push(@cols_row, ($r->{'time'} eq '*' ? $text{'rule_anytime'} : $r->{'time'} ) ) if ($times);
            push(@cols_row, $text{'rule_'.$r->{'action'}}." ".($r->{'log'} ? " $text{'rules_log'}" : "") );
            push(@cols_row, ($r->{'enabled'} ? $text{'yes'} : "<font color=#ff0000>$text{'no'}</font>" ) );
            
            if ($config{'show_desc'}) {
                push(@cols_row, ($r->{'desc'} eq "*" ? "" : $r->{'desc'} ) );
            }
            if ( $rules_cnt > 1 ) {
                $link = "";
                if ($r eq $rules[0] || !$edit) {
                    $link = "<img src=images/gap.gif>";
                } else {
                    $link = &ui_link("up.cgi?idx=".$r->{'index'}, "<img src=images/up.gif border=0>");
                }
                if ($r eq $rules[$#rules] || !$edit) {
                    $link .= "<img src=images/gap.gif>";
                } else {
                    $link .= &ui_link("down.cgi?idx=".$r->{'index'}, "<img src=images/down.gif border=0>");
                }
                push(@cols_row, $link ) if ( $link ne "" );
            }

            foreach (@cols_row) {
                push(@cols_row_tag, $Row_Color );
            }
            print &ui_columns_row(\@cols_row, \@cols_row_tag);
		}
    }
	print &ui_columns_end();
	}
else {
	print "<b>$text{'rules_none'}</b><p>\n";
	}
if ($edit) {
    print &ui_links_row(\@links);
	print "<p>\n";
	}
if ($edit && @rules) {
    print &ui_submit($text{'rules_enable'}, "enable" );
    print &ui_submit($text{'rules_disable'}, "disable" );
	print "&nbsp;\n";
    print &ui_submit($text{'rules_logon'}, "logon" );
    print &ui_submit($text{'rules_logoff'}, "logoff" );
	print "&nbsp;\n";
    print &ui_submit($text{'rules_delete'}, "delete" );
	print &ui_form_end(undef,undef,1);
	}

print &ui_hr();
&footer("", $text{'index_return'});

