global class SLAStatusScheduler implements Schedulable {
    
    global void execute(SchedulableContext sc) {
        
        // 1️⃣ Get Escalation Queue Id
        Id escalationQueueId = [
            SELECT Id
            FROM Group
            WHERE Type = 'Queue'
            AND Name = 'SLA_Escalation_Queue'
            LIMIT 1
        ].Id;
        
        List<SLA_Tracker__c> trackersToUpdate = new List<SLA_Tracker__c>();
        List<Case> casesToUpdate = new List<Case>();
        List<SLA_History__c> historyList = new List<SLA_History__c>();
        
        
        List<SLA_Tracker__c> trackers = [
            SELECT Id,
                   SLA_Deadline__c,
                   SLA_Status__c,
                   Case__c,
                   Case__r.OwnerId,
                   Case__r.Priority
            FROM SLA_Tracker__c
            WHERE SLA_Deadline__c != null AND SLA_Status__c != 'Breached' AND SLA_Status__c != 'Met'
        ];
        
        Datetime nowTime = System.now();
        
        for (SLA_Tracker__c tracker : trackers) {
            
            Long remainingMinutes =
                (tracker.SLA_Deadline__c.getTime() - nowTime.getTime()) / (1000 * 60);
            
            String newStatus;
            
            if (remainingMinutes <= 0) {
                newStatus = 'Breached';
            } else if (remainingMinutes <= 120) {
                newStatus = 'Near Breach';
            } else {
                newStatus = 'Active';
            }
            
            // Update SLA Tracker if status changed
            if (tracker.SLA_Status__c != newStatus) {
                tracker.SLA_Status__c = newStatus;
                trackersToUpdate.add(tracker);
                
                // 🔥 ESCALATION LOGIC
                if (newStatus == 'Breached' && tracker.Case__c != null) {
                    Case c = new Case(
                        Id = tracker.Case__c,
                    OwnerId = escalationQueueId,
                    Priority = 'High'
                        );
                    casesToUpdate.add(c);
                }
                
                //Create SLA History Record
                SLA_History__c history = new SLA_History__c(
                    Case__c = tracker.Case__c,
                Old_Status__c = tracker.SLA_Status__c,
                New_Status__c = newStatus,
                Changed_On__c = System.today()
                    );
                historyList.add(history);
                
            }
        }
        
        if (!trackersToUpdate.isEmpty()) {
            update trackersToUpdate;
        }
        
        if (!historyList.isEmpty()) {
            insert historyList;
        }
        if (!casesToUpdate.isEmpty()) {
            update casesToUpdate;
        }
    }
}