/**
 * @description Holds accumulated metrics for a chained batch job.
 * Used to pass state between paginated API calls in the State-Chaining Batch pattern.
 * This class supports metrics for Productos, Pedidos, and Facturas integrations.
 */
public class BatchSummary {
    public Integer totalRecordsProcessed { get; set; }
    public Integer totalRecordsUpserted { get; set; }
    public Integer totalRecordsSkipped { get; set; }
    
    public Integer totalLinesProcessed { get; set; }
    public Integer totalLinesUpserted { get; set; }
    public Integer totalLinesSkipped { get; set; }
    
    public List<String> errorMessages { get; set; }
    public Integer totalApiCallouts { get; set; }
    public Integer totalPagesProcessed { get; set; }

    public BatchSummary() {
        this.totalRecordsProcessed = 0;
        this.totalRecordsUpserted = 0;
        this.totalRecordsSkipped = 0;
        
        this.totalLinesProcessed = 0;
        this.totalLinesUpserted = 0;
        this.totalLinesSkipped = 0;
        
        this.errorMessages = new List<String>();
        this.totalApiCallouts = 0;
        this.totalPagesProcessed = 0;
    }

    public void addError(String errorMessage) {
        if (this.errorMessages.size() < 50) {
            this.errorMessages.add(errorMessage);
        }
    }

    public void incrementPage() {
        this.totalPagesProcessed++;
    }

    public void incrementCallout() {
        this.totalApiCallouts++;
    }
}
