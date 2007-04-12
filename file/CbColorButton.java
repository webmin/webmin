import java.awt.*;
import java.util.*;

/**A component for choosing a color
 */
public class CbColorButton extends Panel implements CbButtonCallback,
                                                    CbColorWindowCallback
{
	Color col;
	CbButton but;
	Vector pal;
	Image swatch = Util.createImage(32, 16);
	Graphics g = swatch.getGraphics();
	CbColorWindow win;

	CbColorButton(Color c)
	{
	this(c, new Vector());
	}

	CbColorButton(Color c, Vector p)
	{
	if (c == null) c = Color.black;
	col = c;
	g.setColor(col); g.fillRect(0, 0, 32, 16);
	setLayout(new BorderLayout());
	add("Center", but = new CbButton(swatch, this));
	}

	public void click(CbButton b)
	{
	if (win == null)
		win = new CbColorWindow(col, this);
	}

	public void chosen(CbColorWindow w, Color c)
	{
	if (c != null) {
		col = c;
		g.setColor(col); g.fillRect(0, 0, 32, 16);
		but.repaint();
		}
	win = null;
	}

	public Vector palette(CbColorWindow w)
	{
	return pal;
	}
}

