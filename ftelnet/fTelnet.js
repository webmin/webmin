// Probably don't need to change these
var params = {};
params.quality = "high";
params.bgcolor = "#ffffff";
params.allowscriptaccess = "sameDomain";
params.allowfullscreen = "true";

// Probably don't need to change these
var attributes = {};
attributes.id = "fTelnet";
attributes.name = "fTelnet";
attributes.align = "middle";
attributes.swliveconnect = "true";

// This embeds the SWF on the webpage when it loads
swfobject.embedSWF(
  "fTelnet.swf", "divfTelnet", 
  "100%", "100%", 
  "10.0.0", "playerProductInstall.swf", 
  flashvars, params, attributes);

function fTelnetConnect(AHost, APort)
{
  var flash=getFlashObject("fTelnet");
  flash.Connect(AHost, APort);
}

function fTelnetConnected()
{
  var flash=getFlashObject("fTelnet");
  return flash.Connected();
}

function fTelnetDisconnect()
{
  var flash=getFlashObject("fTelnet");
  flash.Disconnect();
}

// Dynamically change the border style of the current flash object
function fTelnetSetBorderStyle(AStyle)
{
  var flash=getFlashObject("fTelnet");
  flashvars.BorderStyle = AStyle;
  flash.SetBorderStyle(flashvars.BorderStyle);
}

// Dynamically change the font size of the current flash object
function fTelnetSetFont(ACodePage, AWidth, AHeight)
{
  var flash=getFlashObject("fTelnet");
  flashvars.CodePage = ACodePage;
  flashvars.FontHeight = AHeight;
  flashvars.FontWidth = AWidth;
  flash.SetFont(flashvars.CodePage, flashvars.FontWidth, flashvars.FontHeight);
}

// Dynamically change the screen size of the current flash object
function fTelnetSetScreenSize(AColumns, ARows)
{
  var flash=getFlashObject("fTelnet");
  flashvars.ScreenColumns = AColumns;
  flashvars.ScreenRows = ARows;
  flash.SetScreenSize(flashvars.ScreenColumns, flashvars.ScreenRows);
}

// Helper function to update the size of the flash object
function fTelnetResize(AWidth, AHeight)
{
  var flash = getFlashObject("fTelnet");
  flash.setAttribute("width", AWidth);
  flash.setAttribute("height", AHeight);
}

// Helper function to get the flash object (cross browser)
function getFlashObject(AID)
{
  if (window.document[AID]) 
  {
      return window.document[AID];
  }
  if (navigator.appName.indexOf("Microsoft Internet")==-1)
  {
    if (document.embeds && document.embeds[AID])
    {
      return document.embeds[AID];
    } 
  }
  else // if (navigator.appName.indexOf("Microsoft Internet")!=-1)
  {
    return document.getElementById(AID);
  }
}
