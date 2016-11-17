/**
 * Stopwatch class to be used as a timer.
 */
public class Stopwatch {

    /**
     * Start time.
     */
    private final long start;

    /**
     * Construct to set current time in milliseconds to start time.
     */
    public Stopwatch() {
        start = System.currentTimeMillis();
    }

    /**
     * Returns time (in milliseconds) since this object was created.
     * @return time in milliseconds
     */
    public double elapsedTime() {
        long now = System.currentTimeMillis();
        return now - start;
    }

}
