public with sharing class ContactContactRelationshipController {  
    //******************************************************************************* */
    // Method to create inverse relationship record
    public static void createInverseRelationship(Set<Id> ContactContactIdList){
        List<ContactContactRelation> newRecordsWithRelations = [
        SELECT Id, ContactId, RelatedContactId, StartDate, EndDate, HierarchyType, OwnerId, 
               PartyRoleRelationId, PartyRoleRelation.RelatedInverseRecordId,
               RelatedInverseRecordId
        FROM ContactContactRelation 
        WHERE Id IN :ContactContactIdList
    ];
    
    System.debug('Number of records to process: ' + newRecordsWithRelations.size());
    System.debug('Records with relations: ' + JSON.serialize(newRecordsWithRelations));

    // Map to store the relationship between Contact pairs and original record
    Map<String, Id> contactPairToOriginalId = new Map<String, Id>();
    List<ContactContactRelation> inverseRelationships = new List<ContactContactRelation>();

    for(ContactContactRelation ccr : newRecordsWithRelations) {
        System.debug('Processing record: ' + ccr.Id);
        System.debug('PartyRoleRelation: ' + ccr.PartyRoleRelation);

        if(ccr.PartyRoleRelation?.RelatedInverseRecordId != null) {
            System.debug('Creating inverse relationship for record: ' + ccr.Id);
            System.debug('Using RelatedInverseRecordId: ' + ccr.PartyRoleRelation.RelatedInverseRecordId);

            // Create a unique key for this contact pair
            String contactPairKey = ccr.RelatedContactId + '-' + ccr.ContactId;

            // Check if an inverse relationship already exists
            if(!contactPairToOriginalId.containsKey(contactPairKey)) {
                contactPairToOriginalId.put(contactPairKey, ccr.Id);

                ContactContactRelation inverseRelationship = new ContactContactRelation(
                    StartDate = ccr.StartDate,
                    EndDate = ccr.EndDate,
                    HierarchyType = ccr.HierarchyType,
                    OwnerId = ccr.OwnerId,
                    PartyRoleRelationId = ccr.PartyRoleRelation.RelatedInverseRecordId,
                    RelatedInverseRecordId = ccr.Id,
                    RelatedContactId = ccr.ContactId,
                    ContactId = ccr.RelatedContactId,
                    IsActive = true
                );
                inverseRelationships.add(inverseRelationship);
            } else {
                System.debug('Skipping duplicate inverse relationship for key: ' + contactPairKey);
            }
        } else {
            System.debug('Skipping record ' + ccr.Id + ' - No RelatedInverseRecordId found');
        }
    }

    System.debug('Number of inverse relationships to create: ' + inverseRelationships.size());

    if(!inverseRelationships.isEmpty()) {
        try {
            // Insert inverse relationships
            insert inverseRelationships;
            System.debug('Successfully created inverse relationships');

            // Query the newly created records to get their IDs and contact relationships
            List<ContactContactRelation> createdInverseRecords = [
                SELECT Id, ContactId, RelatedContactId 
                FROM ContactContactRelation 
                WHERE Id IN :inverseRelationships
            ];

            // Now update the original records with the new inverse record IDs
            List<ContactContactRelation> recordsToUpdate = new List<ContactContactRelation>();

            for(ContactContactRelation inverseRecord : createdInverseRecords) {
                // Recreate the key to match with original record
                String contactPairKey = inverseRecord.ContactId + '-' + inverseRecord.RelatedContactId;
                Id originalRecordId = contactPairToOriginalId.get(contactPairKey);

                if(originalRecordId != null) {
                    recordsToUpdate.add(new ContactContactRelation(
                        Id = originalRecordId,
                        RelatedInverseRecordId = inverseRecord.Id
                    ));
                }
            }

            if(!recordsToUpdate.isEmpty()) {
                update recordsToUpdate;
                System.debug('Successfully updated original records with inverse record IDs');
            }

        } catch(Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error processing relationships: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Error stack trace: ' + e.getStackTraceString());
        }
    } else {
        System.debug('No inverse relationships to create');
    }
    }

    //******************************************************************************* */
    // Method to delete relationship record
    public static void deleteInverseRelationship(List<ContactContactRelation> oldRecords) {
        // Create a Set to store the Related Inverse Record IDs
        Set<Id> inverseRecordIds = new Set<Id>();
        
        // Get the Related Inverse Record IDs directly from the old records
        for(ContactContactRelation ccr : oldRecords) {
            if(ccr.RelatedInverseRecordId != null) {
                inverseRecordIds.add(ccr.RelatedInverseRecordId);
            }
        }
    
        if (!inverseRecordIds.isEmpty()) {
            try {
                List<ContactContactRelation> inverseRecordsToDelete = [
                    SELECT Id 
                    FROM ContactContactRelation 
                    WHERE Id IN :inverseRecordIds
                ];
                
                if(!inverseRecordsToDelete.isEmpty()) {
                    delete inverseRecordsToDelete;
                    System.debug('Successfully deleted inverse relationship records');
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error deleting inverse relationship records: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Error stack trace: ' + e.getStackTraceString());
            }
        } else {
            System.debug('No inverse records found to delete');
        }
    }

    //******************************************************************************* */
    // Method to update relationship record
    public static void updateInverseRelationship(Set<Id> ContactContactIdList) {
        // Query for inverse relationship records
        List<ContactContactRelation> inverseRelationshipRecords = [
            SELECT Id, RelatedInverseRecordId, PartyRoleRelationId, 
                   ContactId, RelatedContactId, 
                   StartDate, EndDate, HierarchyType, OwnerId
            FROM ContactContactRelation 
            WHERE RelatedInverseRecordId IN :ContactContactIdList
        ];
    
        // Create a map of updated record ID to its inverse record
        Map<Id, ContactContactRelation> inverseRecordMap = new Map<Id, ContactContactRelation>();
        for(ContactContactRelation ccr : inverseRelationshipRecords) {
            inverseRecordMap.put(ccr.RelatedInverseRecordId, ccr);
        }
    
        // Query for the original updated records to get their current Party Role Relations
        List<ContactContactRelation> updatedRecords = [
            SELECT Id, ContactId, RelatedContactId, PartyRoleRelationId
            FROM ContactContactRelation 
            WHERE Id IN :ContactContactIdList
        ];
    
        // Prepare a list of inverse records to update
        List<ContactContactRelation> recordsToUpdate = new List<ContactContactRelation>();
    
        for(ContactContactRelation updatedRecord : updatedRecords) {
            // Find the corresponding inverse record
            ContactContactRelation inverseRecord = inverseRecordMap.get(updatedRecord.Id);
            
            if(inverseRecord != null) {
                // Update the inverse record with new Party Role Relation ID
                ContactContactRelation updatedInverseRecord = new ContactContactRelation(
                    Id = inverseRecord.Id,
                    PartyRoleRelationId = updatedRecord.PartyRoleRelationId
                );
                
                recordsToUpdate.add(updatedInverseRecord);
            }
        }
    
        // Perform the update
        if(!recordsToUpdate.isEmpty()) {
            try {
                update recordsToUpdate;
                System.debug('Successfully updated inverse relationships');
            } catch(Exception e) {
                System.debug(LoggingLevel.ERROR, 'Error updating inverse relationships: ' + e.getMessage());
                System.debug(LoggingLevel.ERROR, 'Error stack trace: ' + e.getStackTraceString());
            }
        }
    }


    // Get the inverse records related to the updated records
    // Create a Map of updated record ID as the key and the inverse record as a value
    // Get new Party Role IDs from Trigger.new records
    // Get the inverse Party Role IDs from the above party roles. 
    // Create a map of the current Party Role IDs to the inverse Party Role Ids. Current Id should be the key
    // Loop through updated records and get the inverse record from the map and the inverse party role from the map. 
    // Add the records to the list and update 
}