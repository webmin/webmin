import java.awt.*;
import java.net.*;
import java.io.*;
import java.util.*;
import java.applet.*;

public class LogViewer extends Applet implements Runnable,CbButtonCallback
{
	TextArea log;
	StringBuffer logbuffer = new StringBuffer();
	LineInputStream is;
	Thread th;
	CbButton pause, button;
	boolean paused = false;

	public void init()
	{
	// Create the UI
	setLayout(new BorderLayout());
	add("Center", log = new TextArea());
	log.setEditable(false);
	Util.setFont(new Font("TimesRoman", Font.PLAIN, 12));
	Panel bot = new Panel();
	bot.setBackground(Color.white);
	bot.setForeground(Color.white);
	bot.setLayout(new FlowLayout(FlowLayout.RIGHT));
	if (getParameter("pause") != null) {
		// Add button to pause display
		bot.add(pause = new CbButton("  Pause  ", this));
		}
	if (getParameter("buttonname") != null) {
		// Add button for some other purpose
		bot.add(button = new CbButton(getParameter("buttonname"),this));
		}
	add("South", bot);
	}

	public void start()
	{
	// Start download thread
	log.setText("");
	th = new Thread(this);
	th.start();
	}

	public void stop()
	{
	// Stop download
	try {
		String killurl = getParameter("killurl");
		if (killurl != null) {
			// Call this CGI at stop time
			try {
				URL u = new URL(getDocumentBase(), killurl);
				URLConnection uc = u.openConnection();
				String session = getParameter("session");
				if (session != null)
				    uc.setRequestProperty("Cookie", session);
				uc.getInputStream().close();
				}
			catch(Exception e2) { }
			}
		if (is != null) is.close();
		if (th != null) th.stop();
		}
	catch(Exception e) {
		// ignore it
		e.printStackTrace();
		}
	}

	public void run()
	{
	try {
		URL u = new URL(getDocumentBase(), getParameter("url"));
		URLConnection uc = u.openConnection();
		String session = getParameter("session");
		if (session != null)
			uc.setRequestProperty("Cookie", session);
		is = new LineInputStream(uc.getInputStream());
		while(true) {
			String l = is.gets();
			append(l);
			}
		}
	catch(EOFException e) {
		// end of file ..
		}
	catch(IOException e) {
		// shouldn't happen!
		e.printStackTrace();
		append("IO error : "+e.getMessage());
		}
	}

	int len = 0, oldlen = 0;

	void append(String str) {
		if (!paused) {
			log.append((len == 0 ? "" : "\n")+str);
			}
		logbuffer.append((len == 0 ? "" : "\n")+str);
		oldlen = len;
		len += str.length()+1;
		if (!paused) {
			log.select(oldlen, oldlen);
			}
	}

	public void click(CbButton b) {
		if (b == pause) {
			if (paused) {
				// Resume display, and append missing text
				pause.setText("  Pause  ");
				log.setText(logbuffer.toString());
				log.select(oldlen, oldlen);
			} else {
				// Stop display
				pause.setText("Resume");
			}
			paused = !paused;
		} else if (b == button) {
			// Open some page
			try {
				URL u = new URL(getDocumentBase(),
						getParameter("buttonlink"));
				getAppletContext().showDocument(u);
				}
			catch(Exception e) { }
		}
	}
}

