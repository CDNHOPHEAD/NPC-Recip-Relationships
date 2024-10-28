trigger ContactContactRelationTrigger on ContactContactRelation (after insert) {
    System.debug('Trigger.new: ' + JSON.serialize(Trigger.new));

    // Get full records with relationships
    List<ContactContactRelation> newRecordsWithRelations = [
        SELECT Id, ContactId, RelatedContactId, StartDate, EndDate, HierarchyType, OwnerId, 
               PartyRoleRelationId, PartyRoleRelation.RelatedInverseRecordId,
               RelatedInverseRecordId
        FROM ContactContactRelation 
        WHERE Id IN :Trigger.newMap.keySet()
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
