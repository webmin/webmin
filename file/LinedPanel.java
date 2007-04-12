import java.awt.*;

class LinedPanel extends GrayPanel
{
	String title;

	LinedPanel(String t)
	{
	title = t;
	}

	public void paint(Graphics g)
	{
	super.paint(g);
	Font f = g.getFont();
	FontMetrics fnm = g.getFontMetrics();
	int w = size().width-1, h = size().height - 1;
	int tl = fnm.stringWidth(title);

	g.setColor(Util.light_edge);
	g.drawLine(5, 5, 5, h-5);
	g.drawLine(5, h-5, w-5, h-5);
	g.drawLine(w-5, h-5, w-5, 5);
	g.drawLine(tl+9, 5, w-5, 5);

	g.setColor(Util.dark_edge);
	g.drawLine(4, 4, 4, h-6);
	g.drawLine(6, h-6, w-6, h-6);
	g.drawLine(w-6, h-6, w-6, 6);
	g.drawLine(w-6, 4, tl+9, 4);
	g.drawString(title, 7, fnm.getAscent());
	}

	public Insets insets()
	{
	return new Insets(15, 10, 10, 10);
	}
}

