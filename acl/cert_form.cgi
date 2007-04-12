#!/usr/local/bin/perl
# cert_form.cgi

require './acl-lib.pl';
&ui_print_header(undef, $text{'cert_title'}, "", undef, undef, undef, undef, undef, undef,
	"language=VBSCRIPT onload='postLoad()'");
eval "use Net::SSLeay";

print "<p>$text{'cert_msg'}<p>\n";
if ($ENV{'SSL_USER'}) {
	print &text('cert_already', "<tt>$ENV{'SSL_USER'}</tt>"),
	      "<p>\n";
	}

if ($ENV{'HTTP_USER_AGENT'} =~ /MSIE/i) {
	# Special VBscript and ActiveX hacks are needed for IE 
	print <<EOF;
<OBJECT classid="clsid:127698e4-e730-4e5c-a2b1-21490a70c8a1" sXEnrollVersion="5,131,3659,0" codebase="xenroll.dll" id=Enroll>
</OBJECT>

<SCRIPT type="text/vbscript">
Option Explicit

Function MakeKeyFlags(keysize)
  Dim flags
  ' If CRYPT_EXPORTABLE is set, the generated private key can be exported 
  ' from IE in passphrase protected pkcs12 envelope.
  ' If CRYPT_USER_PROTECTED is set, the user is allowed to select security
  ' level for the generated private key. If not set the lowest security
  ' level is set as default. This means that private key is not protected
  ' on local disk and user is not prompted is the key is used to sign data.
  Const CRYPT_EXPORTABLE = 1
  Const CRYPT_USER_PROTECTED = 2
  If document.certform.protectkey.checked = true Then
    flags = CRYPT_EXPORTABLE Or CRYPT_USER_PROTECTED
  Else
    flags = CRYPT_EXPORTABLE 
  End If
  MakeKeyFlags = flags Or ( keysize * 65536)
End Function

Function CreatePKCS10Request(keysize)
  Dim DNName
  Const AT_KEYEXCHANGE = 1
  Const AT_SIGNATURE = 2
  DNName = "CN="+document.requestData.commonName.value+", O="+document.requestData.organizationName.value+", OU="+document.requestData.organizationalUnitName.value+", ST="+document.requestData.stateOrProvinceName.value+", C="+document.requestData.countryName.value+", Email="+document.requestData.emailAddress.value
  Enroll.RequestStoreFlags = &H20000
  ' document.requestData.storeflags.value = "&H20000"
  Enroll.GenKeyFlags = MakeKeyFlags(keysize)
  Enroll.KeySpec = AT_KEYEXCHANGE
  CreatePKCS10Request = Enroll.createPKCS10(DNName, "")
End Function


sub CertRequestSub
  Dim keysize
  keysize = document.certform.keysize.value
  document.requestData.data.value = CreatePKCS10Request(keysize)
  document.requestData.action.value = "submit"
  document.requestData.reqkeysize.value = keysize
  document.requestData.submit()
end sub

sub CertRequestEdit
  Dim keysize
  keysize = document.certform.keysize.value
  document.requestData.data.value = CreatePKCS10Request(keysize)
  document.requestData.action.value = "edit"
  document.requestData.reqkeysize.value = keysize
  document.requestData.submit()
end sub


'-----------------------------------------------------------------
' IE SPECIFIC:
' Get the list of CSPs from Enroll
' returns error number
' assumes Enroll is named 'Enroll' and the list box is 'document.certform.lbCSP'
Function GetCSPList()
  On Error Resume Next
  Dim nProvType, nOrigProvType, nTotCSPs, nDefaultCSP, bNoDssBase, bNoDssDh, sUserAgent
  ' should be >= the number of providers defined in wincrypt.h (~line 431)
  Const nMaxProvType=25 
  nTotCSPs=0
  nDefaultCSP=-1

  sUserAgent=navigator.userAgent
  If CInt(Mid(sUserAgent, InStr(sUserAgent, "MSIE")+5, 1))<=4 Then
    bNoDssDh=True
    bNoDssBase=True
  Else
    bNoDssDh=False
    If 0<>InStr(sUserAgent, "95") Then
      bNoDssBase=True
    ' NT 4 does not include version num in string.
    ElseIf 0<>InStr(sUserAgent, "NT)") Then 
      bNoDssBase=True
    Else
      bNoDssBase=False
    End If
  End If

  ' save the original provider type
  nOrigProvType=Enroll.ProviderType
  If 0 <> Err.Number Then
    ' something wrong with Enroll
    GetCSPList=Err.Number 
    Exit Function
  End If

  ' enumerate through each of the provider types
  For nProvType=0 To nMaxProvType 
    Dim nCSPIndex
    nCSPIndex=0
    Enroll.ProviderType=nProvType
			
    ' enumerate through each of the providers for this type
    Do 
      Dim sProviderName
      'get the name
      sProviderName=Enroll.enumProviders(nCSPIndex, 0)
				
      If &H80070103=Err.Number Then 
        ' no more providers
        Err.Clear
        Exit Do
      ElseIf 0<>Err.Number Then
        ' something wrong with Enroll
        '  - ex, Win16 IE4 Enroll doesn't support this call.
        GetCSPList=Err.Number 
        Exit Function
      End If
    
      If ("Microsoft Base DSS Cryptographic Provider"=sProviderName And True=bNoDssBase) _
        Or ("Microsoft Base DSS and Diffie-Hellman Cryptographic Provider"=sProviderName And True=bNoDssDh) Then
        ' skip this provider
      Else 
        ' For each provider, add an element to the list box.
        Dim oOption
        Set oOption=document.createElement("Option")
        oOption.text=sProviderName
        oOption.Value=nProvType
        document.certform.lbCSP.add(oOption)
        If InStr(sProviderName, "Microsoft Enhanced Cryptographic Provider") <> 0 Then
    	  oOption.selected=True
	  nDefaultCSP=nTotCSPs
        End If
	nTotCSPs=nTotCSPs+1
      End If
				
      ' get the next provider
      nCSPIndex=nCSPIndex+1
    Loop
  Next
		
  ' if there are no CSPs, we're kinda stuck
  If 0=nTotCSPs Then
    Set oElement=document.createElement("Option")
    oElement.text="-- No CSP's found --"
    document.certform.lbCSP.Options.Add(oElement)
  End If

  ' remove the 'loading' text
  document.certform.lbCSP.remove(0)

  ' select the default provider
  If -1 <> nDefaultCSP Then
    document.certform.lbCSP.selectedIndex=nDefaultCSP
  End If

  ' restore the original provider type
  Enroll.ProviderType=nOrigProvType

  ' set the return value and exit
  If 0 <> Err.Number Then
    GetCSPList=Err.Number
    ElseIf 0 = nTotCSPs Then
    ' signal no elements with -1
    GetCSPList=-1
  Else
    GetCSPList=0
  End If
End Function


Function postLoad()
  On Error Resume Next   
  Dim nResult  
  nResult = 0
  ' get the CSP list
  nResult = GetCSPList()
  if 0 <> nResult Then
    Exit Function
  end if
  handleCSPChange()
End Function

Function handleCSPChange()
    Dim g_bOkToSubmit, nCSPIndex, nProvType, nSupportedKeyUsages
    Dim keymax, keymin

    ' IE is not ready until Enroll has been loaded
    g_bOkToSubmit = false

    ' some constants defined in wincrypt.h:
    Const CRYPT_EXPORTABLE = 1
    Const CRYPT_USER_PROTECTED = 2
    Const CRYPT_MACHINE_KEYSET = &H20
    Const AT_KEYEXCHANGE = 1
    Const AT_SIGNATURE = 2
    Const CERT_SYSTEM_STORE_LOCAL_MACHINE = &H20000
    Const ALG_CLASS_ANY = 0
    Const ALG_CLASS_SIGNATURE = &H2000
    Const ALG_CLASS_HASH = &H4000
    Const PROV_DSS=3
    Const PROV_DSS_DH=13

    ' convenience constants, for readability
    Const KEY_LEN_MIN=true
    Const KEY_LEN_MAX=false
    Const KEY_USAGE_EXCH=0
    Const KEY_USAGE_SIG=1
    Const KEY_USAGE_BOTH=2

    ' defaults
    Const KEY_LEN_MIN_DEFAULT=384
    Const KEY_LEN_MAX_DEFAULT=16384

    nCSPIndex = document.certform.lbCSP.selectedIndex
    Enroll.ProviderName = document.certform.lbCSP.options(nCSPIndex).text
    nProvType = document.certform.lbCSP.options(nCSPIndex).value
    Enroll.ProviderType = nProvType
    


    nSupportedKeyUsages = AT_KEYEXCHANGE



    if (PROV_DSS = nProvType OR PROV_DSS_DH = nProvType) then
     nSupportedKeyUsages = AT_SIGNATURE
    end if

    document.certform.keyusage.value="both"


End Function
</SCRIPT>

<form name="requestData" action="cert_issue_ie.cgi" method=post>

<input type="hidden" name="data">
<input type="hidden" name="action" value="">
<input type="hidden" name="reqkeysize" value="">

<table border>
<tr $tb> <td><b>$text{'cert_header'}</b></td> </tr>
<tr $cb> <td><table>
<tr> <td> <b>$text{'cert_cn'}</b> </td>       
<td> <input type="text" size=30 name="commonName" value=""> 
</td> </tr>
<tr> <td> <b>$text{'cert_email'}</b> </td>       
<td> <input type="text" size=30 name="emailAddress" value=""> 
</td> </tr>
<tr> <td> <b>$text{'cert_ou'}</b> </td> 
<td> <input type="text" size=30 name="organizationalUnitName" value=""> 
</td> </tr>
<tr> <td> <b>$text{'cert_o'}</b> </td>      
<td> <input type="text" size=30 name="organizationName" value=""> 
</td> </tr>
<tr> <td> <b>$text{'cert_sp'}</b> </td>           
<td> <input type="text" size=15 name="stateOrProvinceName" value=""> 
</td> </tr>
<tr> <td> <b>$text{'cert_c'}</b> </td>           
<td> <input type="text" size=2 name="countryName" value=""> 
</td> </tr>

<input type="hidden" name="storeflags" value="">
</form>

<form name="certform">

<tr><td><b>CSP</b></td>
<td><select name="lbCSP" onchange="handleCSPChange()" language="VBSCRIPT"> 
<option id=locLoading selected>Loading...
</select></td></tr>

<tr>
<td><b>Key size</b></td>
<td><select name=keysize>
<option value=512> 512
<option value=1024 selected> 1024
<option value=2048> 2048
</select>
bits.
<em> Please note that not all CSP's support all key sizes. </em>
</td></tr>
<input type=hidden name=keyusage value="signature">

<input type="hidden" name="storeflags" value="">

<tr> <td><b>Private key protection</b></td>
<td><input type="checkbox" name="protectkey" value="protectkey" checked>
<em>Adds additional security options to private key storage.</em></td> </tr>

</table></td></tr></table>

<input type="button" name="request" value="Submit Request"
       onClick="CertRequestSub" language="VBSCRIPT"
       src="icons/submitrequest.gif" border=0>
</form>

EOF
	}
elsif ($ENV{'HTTP_USER_AGENT'} =~ /Mozilla/i) {
	# Output a form that works for netscape and mozilla
	print "<form action=cert_issue.cgi>\n";
	print "<table border>\n";
	print "<tr $tb> <td><b>$text{'cert_header'}</b></td> </tr>\n";
	print "<tr $cb> <td><table>\n";

	print "<tr> <td><b>$text{'cert_cn'}</b></td>\n";
	print "<td><input name=commonName size=30></td> </tr>\n";

	print "<tr> <td><b>$text{'cert_email'}</b></td>\n";
	print "<td><input name=emailAddress size=30></td> </tr>\n";

	print "<tr> <td><b>$text{'cert_ou'}</b></td>\n";
	print "<td><input name=organizationalUnitName size=30></td> </tr>\n";

	print "<tr> <td><b>$text{'cert_o'}</b></td>\n";
	print "<td><input name=organizationName size=30></td> </tr>\n";

	print "<tr> <td><b>$text{'cert_sp'}</b></td>\n";
	print "<td><input name=stateOrProvinceName size=15></td> </tr>\n";

	print "<tr> <td><b>$text{'cert_c'}</b></td>\n";
	print "<td><input name=countryName size=2></td> </tr>\n";

	print "<tr> <td><b>$text{'cert_key'}</b></td>\n";
	print "<td><keygen name=key></td> </tr>\n";

	print "</table></td></tr></table>\n";
	print "<input type=submit value='$text{'cert_issue'}'>\n";
	print "</form>\n";
	}
else {
	# Unsupported browser!
	print "<p><b>",&text('cert_ebrowser',
			     "<tt>$ENV{'HTTP_USER_AGENT'}</tt>"),"</b><p>\n";
	}

&ui_print_footer("", $text{'index_return'});

