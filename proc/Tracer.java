import java.awt.*;
import java.net.*;
import java.io.*;
import java.util.*;
import java.applet.*;

public class Tracer extends Applet implements Runnable,CbButtonCallback
{
	MultiColumn log;
	StringBuffer logbuffer = new StringBuffer();
	LineInputStream is;
	Thread th;
	CbButton pause, button;
	boolean paused = false;
	int MAX_ROWS = 1000;
	Vector buffer = new Vector();

	public void init()
	{
	// Create the UI
	setLayout(new BorderLayout());
	String cols[] = { "Time", "System Call", "Parameters", "Return" };
	add("Center", log = new MultiColumn(cols));
	float widths[] = { .1f, .15f, .65f, .1f };
	log.setWidths(widths);
	Util.setFont(new Font("TimesRoman", Font.PLAIN, 12));
	Panel bot = new Panel();
	bot.setBackground(Color.white);
	bot.setForeground(Color.white);
	bot.setLayout(new FlowLayout(FlowLayout.RIGHT));
	bot.add(pause = new CbButton("  Pause  ", this));
	add("South", bot);
	}

	public void start()
	{
	// Start download thread
	log.clear();
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
			StringSplitter tok =
				new StringSplitter(is.gets(), '\t', false);
			if (tok.countTokens() == 4) {
				Object row[] = { tok.nextToken(),
						 tok.nextToken(),
						 tok.nextToken(),
						 tok.nextToken() };
				if (paused) {
					// Store in temp buffer
					buffer.addElement(row);
					if (buffer.size() > MAX_ROWS) {
						buffer.removeElementAt(0);
						}
					}
				else {
					// Add immediately
					log.addItem(row);
					cleanup();
					log.scrollto(log.count()-1);
					}
				}
			}
		}
	catch(EOFException e) {
		// end of file ..
		}
	catch(IOException e) {
		// shouldn't happen!
		e.printStackTrace();
		}
	}

	void cleanup()
	{
	while(log.count() > MAX_ROWS) {
		log.deleteItem(0);
		}
	}

	public void click(CbButton b) {
		if (b == pause) {
			if (paused) {
				// Resume display, and add missed stuff
				pause.setText("  Pause  ");
				for(int i=0; i<buffer.size(); i++) {
					Object row[] =
						(Object[])buffer.elementAt(i);
					log.addItem(row);
					}
				cleanup();
				log.scrollto(log.count()-1);
				buffer.removeAllElements();
			} else {
				// Stop display
				pause.setText("Resume");
			}
			paused = !paused;
		}
	}
}

