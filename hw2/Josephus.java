import java.util.ArrayDeque;
import java.util.LinkedList;

/**
 * 08722 Data Structures for Application Programmers.
 * Homework Assignment 2
 * Solve Josephus problem with different data structures
 * and different algorithms and compare running times
 *
 * Andrew ID: shaoleis
 * @author Shaolei Shen
 */
public class Josephus {

    /**
     * Uses ArrayDeque class as Queue/Deque to find the survivor's position.
     * @param size Number of people in the circle that is bigger than 0
     * @param rotation Elimination order in the circle. The value has to be greater than 0
     * @return The position value of the survivor
     */
    public int playWithAD(int size, int rotation) {
        // TODO your implementation here
        // check input
        if (size <= 0 || rotation <= 0) {
            throw new RuntimeException();
        }
        // set up initial array deque
        ArrayDeque<Integer> arrayDeque = new ArrayDeque<Integer>();
        for (int i = 0; i < size; i++) {
            arrayDeque.addLast(i + 1);
        }

        // remove
        int removeIdx;
        while (arrayDeque.size() > 1) {
            // System.out.println(arrayDeque);
            removeIdx = rotation % arrayDeque.size();
            for (int i = 0; i < removeIdx; i++) {
                arrayDeque.addLast(arrayDeque.removeFirst());
            }
            // System.out.println("index is " + removeIdx + ", remove " + arrayDeque.peekLast());
            arrayDeque.removeLast();
        }
        return arrayDeque.getFirst();
    }

    /**
     * Uses LinkedList class as Queue/Deque to find the survivor's position.
     * @param size Number of people in the circle that is bigger than 0
     * @param rotation Elimination order in the circle. The value has to be greater than 0
     * @return The position value of the survivor
     */
    public int playWithLL(int size, int rotation) {
        // TODO your implementation here
        // check input first
        if (size <= 0 || rotation <= 0) {
            throw new RuntimeException();
        }

        LinkedList<Integer> sequence = new LinkedList<Integer>();
        for (int i = 0; i < size; i++) {
            sequence.addLast(i + 1);
        }

        // remove
        int removeIdx;
        while (sequence.size() > 1) {
            // System.out.println(sequence);
            removeIdx = rotation % sequence.size();
            for (int i = 0; i < removeIdx; i++) {
                sequence.addLast(sequence.removeFirst());
            }
            // System.out.println("position is " + removeIdx + ", remove " + sequence.peekLast());
            sequence.removeLast();
        }
        return sequence.getFirst();
    }

    /**
     * Uses LinkedList class to find the survivor's position.
     * However, do NOT use the LinkedList as Queue/Deque
     * Instead, use the LinkedList as "List"
     * That means, it uses index value to find and remove a person to be executed in the circle
     *
     * Note: Think carefully about this method!!
     * When in doubt, please visit one of the office hours!!
     *
     * @param size Number of people in the circle that is bigger than 0
     * @param rotation Elimination order in the circle. The value has to be greater than 0
     * @return The position value of the survivor
     */
    public int playWithLLAt(int size, int rotation) {
        // TODO your implementation here
        // check input first
        if (size <= 0 || rotation <= 0) {
            throw new RuntimeException();
        }

        LinkedList<Integer> sequence = new LinkedList<Integer>();
        for (int i = 0; i < size; i++) {
            sequence.addLast(i + 1);
        }

        int ptr = 0;

        while (sequence.size() > 1) {
            ptr += rotation % sequence.size();
            if (ptr >= sequence.size()) {
                ptr -= sequence.size();
            }
            if (ptr != 0) {
                sequence.remove(--ptr);
            } else {
                sequence.removeLast();
            }
            // System.out.println(sequence);
        }
        return sequence.getFirst();
    }

}
