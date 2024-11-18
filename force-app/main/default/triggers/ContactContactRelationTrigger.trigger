trigger ContactContactRelationTrigger on ContactContactRelation (after insert, after update, after delete) {
    switch on Trigger.operationType {
        when AFTER_INSERT {
            System.debug('Trigger.new: ' + JSON.serialize(Trigger.new));
            ContactContactRelationshipController.createInverseRelationship(Trigger.newMap.keySet());
        }
        when AFTER_DELETE {
            System.debug('Records Deleted::: ' + Trigger.oldMap.keySet());
            ContactContactRelationshipController.deleteInverseRelationship(Trigger.old);
        }
        when AFTER_UPDATE {
            Set<Id> recordsToUpdateInverse = new Set<Id>();
            
            for(ContactContactRelation newRecord : Trigger.new) {
                ContactContactRelation oldRecord = Trigger.oldMap.get(newRecord.Id);
                
                // Check if Party Role Relation has changed
                if(newRecord.PartyRoleRelationId != oldRecord.PartyRoleRelationId) {
                    recordsToUpdateInverse.add(newRecord.Id);
                }
            }
            
            if(!recordsToUpdateInverse.isEmpty()) {
                ContactContactRelationshipController.updateInverseRelationship(recordsToUpdateInverse);
            }
        }
    }
}