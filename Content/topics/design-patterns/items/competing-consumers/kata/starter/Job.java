// A unit of work. STOP is the poison pill that tells one worker to quit.
record Job(int id, int cost) {
    static final Job STOP = new Job(-1, 0);
}

// What a worker does with each job. It may throw.
interface JobHandler {
    void handle(Job job) throws Exception;
}
