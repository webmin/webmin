public class QuickSort
{
    static int col, dir;

    // Sorts entire array
    public static void sort(RemoteFile array[], int c, int d)
    {
	col = c;
	dir = d;
        psort(array, 0, array.length - 1);
    }

    // Sorts partial array
    public static void psort(RemoteFile array[], int start, int end)
    {
        int p;
        if (end > start)
        {
            p = partition(array, start, end);
            psort(array, start, p-1);
            psort(array, p+1, end);
        }
    }

    protected static int compare(RemoteFile a, RemoteFile b) {
	long rv = 0;
	if (col == 1)
		rv = a.name.toLowerCase().compareTo(b.name.toLowerCase());
	else if (col == 2)
		rv = a.size - b.size;
	else if (col == 3)
		rv = a.user.compareTo(b.user);
	else if (col == 4)
		rv = a.group.compareTo(b.group);
	else
		rv = a.modified - b.modified;
	rv = rv < 0 ? -1 : rv > 0 ? 1 : 0;
	return (int)(dir == 2 ? -rv : rv);
    }

    protected static int partition(RemoteFile array[], int start, int end)
    {
        int left, right;
        RemoteFile partitionElement;

        // Arbitrary partition start...there are better ways...
        partitionElement = array[end];

        left = start - 1;
        right = end;
        for (;;)
        {
            while (compare(partitionElement, array[++left]) == 1)
            {
                if (left == end) break;
            }
            while (compare(partitionElement, array[--right]) == -1)
            {
                if (right == start) break;
            }
            if (left >= right) break;
            swap(array, left, right);
        }
        swap(array, left, end);

        return left;
    }

    protected static void swap(RemoteFile array[], int i, int j)
    {
        RemoteFile temp;
	temp = array[i];
	array[i] = array[j];
	array[j] = temp;
    }
}

