/**
 * 08722 Data Structures for Application Programmers.
 * Homework Assignment 2 Solve Josephus Problem
 *
 * Objectives:
 * 1. Understand how Queue/Deque can be used as an aid in an algorithm.
 * 2. Explore and compare different data structures
 * (ArrayDeque and LinkedList) and their operations to solve the same problem.
 */
public class HW2Driver {

    /**
     * A simple test program.
     * @param args arguments
     */
    public static void main(String[] args) {
        // the size and rotation values to be changed for testing
        int size = 100000;
        int rotation = 30000;

        Josephus game = new Josephus();
        Stopwatch timer1 = new Stopwatch();
        System.out.println("Survivor's position: " + game.playWithAD(size, rotation));
        System.out
                .println("Computing time with ArrayDeque used as Queue/Deque: " + timer1.elapsedTime() + " millisec.");

        Stopwatch timer2 = new Stopwatch();
        System.out.println("Survivor's position: " + game.playWithLL(size, rotation));
        System.out
                .println("Computing time with LinkedList used as Queue/Deque: " + timer2.elapsedTime() + " millisec.");

        Stopwatch timer3 = new Stopwatch();
        System.out.println("Survivor's position: " + game.playWithLLAt(size, rotation));
        System.out
                .println("Computing time with LinkedList (remove with index) : " + timer3.elapsedTime() + " millisec.");
    }

}
