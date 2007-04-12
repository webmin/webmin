import java.awt.*;
import java.util.*;

class ErrorWindow extends FixedFrame implements CbButtonCallback
{
	CbButton ok;

	ErrorWindow(String m)
	{
	setLayout(new BorderLayout());
	Panel cen = new BorderPanel(1);
	StringTokenizer tok = new StringTokenizer(m, "\r\n");
	cen.setLayout(new GridLayout(tok.countTokens(), 1));
	while(tok.hasMoreTokens()) {
		cen.add(new Label(tok.nextToken()));
		}
	add("Center", cen);
	Panel bot = new GrayPanel();
	bot.setLayout(new FlowLayout(FlowLayout.CENTER));
	bot.add(new CbButton("Ok", this));
	add("South", bot);
	pack();
	show();
	setTitle("Error");
	Util.recursiveBackground(this, Util.body);
	}

	public void click(CbButton b)
	{
	dispose();
	}
}


