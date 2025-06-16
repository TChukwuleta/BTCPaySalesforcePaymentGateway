public with sharing class DaoService {
    
    // Method to get the sobject record using the id
    public static SObject getSobjectById(String objectId,List<String> listOfFields,Schema.SObjectType objectType){
        String selectSobjectById = 'SELECT {0} FROM {1} WHERE Id = {2}';
        String queryFields = '';
        for(String field : listOfFields){
            queryFields = queryFields + field + ', ';
        }
		queryFields = queryFields.substring(0, queryFields.length()-2);
        String objectName = objectType.getDescribe().getName();
        objectId = '\''+objectId+'\'';
        String queryString = String.format(selectSobjectById,new List<String>{queryFields,objectName,objectId});
        SObject objectRecord = Database.query(queryString)[0];
        return objectRecord;
    }
}