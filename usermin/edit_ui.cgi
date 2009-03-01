#!/usr/local/bin/perl
# edit_ui.cgi
# Edit user interface options

require './usermin-lib.pl';
$access{'ui'} || &error($text{'acl_ecannot'});
&ui_print_header(undef, $text{'ui_title'}, "");

&get_usermin_config(\%uconfig);
print $text{'ui_desc'},"<p>\n";

print &ui_form_start("change_ui.cgi", "post");
print &ui_table_start($text{'ui_header'}, undef, 2, [ "width=30%" ]);


for($i=0; $i<@webmin::cs_names; $i++) {
	$cd = $webmin::cs_codes[$i];
	print &ui_table_row($webmin::cs_names[$i],
	        &ui_opt_textbox($cd, $uconfig{$cd}, 8, $text{'ui_default'},
	          $text{'ui_rgb'}));
	}

print &ui_table_row($text{'ui_texttitles'},
      &ui_yesno_radio("texttitles", int($uconfig{'texttitles'})));

print &ui_table_row($text{'ui_sysinfo'},
      &ui_select("sysinfo", int($uconfig{'sysinfo'}),
      [ map { [ $_, $text{'ui_sysinfo'.$_} ] } (0, 1, 4, 2, 3) ]));

print &ui_table_row($text{'ui_hostnamemode'},
      &ui_select("hostnamemode", int($uconfig{'hostnamemode'}),
      [ map { [ $_, $text{'ui_hnm'.$_} ] } (0 .. 3) ]).
      " ".&ui_textbox("hostnamedisplay", $uconfig{'hostnamedisplay'}, 20));

print &ui_table_row($text{'ui_showlogin'},
      &ui_yesno_radio("showlogin", $uconfig{'showlogin'}));

print &ui_table_row($text{'startpage_nohost'},
      &ui_radio("nohostname", $uconfig{'nohostname'} ? 1 : 0,
		  [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]));

print &ui_table_row($text{'startpage_gotoone'},
      &ui_yesno_radio("gotoone", int($uconfig{'gotoone'})));

@modules = &list_modules();
print &ui_table_row($text{'startpage_gotomodule'},
      &ui_select("gotomodule", $uconfig{'gotomodule'},
      [ [ "", $text{'startpage_gotonone'} ],
      map { [ $_->{'dir'}, $_->{'desc'} ] }
          sort { $a->{'desc'} cmp $b->{'desc'} } @modules ]));

print &ui_table_row($text{'ui_feedbackmode'},
      &ui_radio('feedback_def',
        $uconfig{'feedback'} ? 0 : 1,
        [ [ 0, $text{'ui_feedbackyes'} . ' '
            . &ui_textbox('feedback', $uconfig{'feedback'}) ]
        , [ 1, $text{'no'} ] ]));

print &ui_table_row($text{'ui_feedbackmail'},
      &ui_radio('feedbackmail_def',
        $uconfig{'feedbackmail'} ? 0 : 1,
        [ [ 1, $text{'ui_feedbackmail1'} ]
        , [ 0, $text{'ui_feedbackmail0'} . ' '
            . &ui_textbox('feedbackmail', $uconfig{'feedbackmail'}) ] ]));

print &ui_table_row($text{'ui_feedbackhost'},
        &ui_opt_textbox("feedbackhost", $uconfig{'feedbackhost'}, 30,
          $text{'ui_feedbackthis'}));

print &ui_table_row($text{'ui_tabs'},
	&ui_radio("notabs", $uconfig{'notabs'} ? 1 : 0,
	  [ [ 0, $text{'yes'} ], [ 1, $text{'no'} ] ]));

print &ui_table_row($text{'ui_dateformat'},
	&ui_select("dateformat", $uconfig{'dateformat'} || "dd/mon/yyyy",
	  [ map { [ $_, $text{'ui_dateformat_'.$_} ] }
	    @webmin::webmin_date_formats ]));

print &ui_table_end();
print &ui_form_end([ [ "save", $text{'save'} ] ]);

&ui_print_footer("", $text{'index_return'});

