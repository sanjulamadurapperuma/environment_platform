import ballerina/config as conf;
import ballerina/mongodb;

// Mongodb configurations.
mongodb:ClientConfig mongoConfig = {
    host: conf:getAsString("DB_HOST"),
    username: conf:getAsString("DB_USER_NAME"),
    password: conf:getAsString("DB_PASSWORD"),
    options: {sslEnabled: false, serverSelectionTimeout: 500}
};
mongodb:Client mongoClient = check new (mongoConfig);
mongodb:Database mongoDatabase = check mongoClient->getDatabase("EnvironmentPlatform");
mongodb:Collection applicationCollection = check mongoDatabase->getCollection("applications");

# The `saveApplication` function will post the application to the applications collection in the database.
# 
# + form - The TreeRemovalForm Type record is accepted.
# + return - This function will return null if application is added to the database or else return mongodb:Database error.
function saveApplication(TreeRemovalForm form) returns error? {

    // Make the location json.
    json[] locations = [];
    foreach Location location in form.area {
        locations.push(<json>{"Latitude": location.latitude, "longitude": location.longitude});
    }

    // Make the treeInformation json.
    json[] treeInformation = [];
    foreach TreeInformation treeInfo in form.treeInformation {
        json[] logDetails = [];
        foreach var item in treeInfo.logDetails {
            logDetails.push(<json>{"minGirth": item.minGirth, "maxGirth": item.maxGirth, "height": item.height});
        }
        treeInformation.push(<json>{
            "species": treeInfo.species,
            "treeNumber": treeInfo.treeNumber,
            "heightType": treeInfo.heightType,
            "height": treeInfo.height,
            "girth": treeInfo.girth,
            "logDetails": logDetails
        });
    }

    // Construct the application.
    map<json> application = {
        "applicationId": "tcf-20200513",
        "status": form.status,
        "numberOfVersions": 1,
        "versions": [
                {
                    "title": form.title,
                    "applicationCreatedDate": {
                        "year": form.applicationCreatedDate.year,
                        "month": form.applicationCreatedDate.month,
                        "day": form.applicationCreatedDate.day,
                        "hour": form.applicationCreatedDate.hour,
                        "minute": form.applicationCreatedDate.minute
                    },
                    "removalDate": {
                        "year": form.removalDate.year,
                        "month": form.removalDate.month,
                        "day": form.removalDate.day,
                        "hour": form.removalDate.hour,
                        "minute": form.removalDate.minute
                    },
                    "reason": form.reason,
                    "applicationType": form.applicationType,
                    "requestedBy": form.requestedBy,
                    "permitRequired": form.permitRequired,
                    "landOwner": form.landOwner,
                    "treeRemovalAuthority": form.treeRemovalAuthority,
                    "city": form.city,
                    "district": form.district,
                    "nameOfTheLand": form.nameOfTheLand,
                    "planNumber": form.planNumber,
                    "area": locations,
                    "treeInformation": treeInformation
                }
            ]
    };
    return applicationCollection->insert(application);
}

# The `deleteApplication` function will delete application drafts only which status is save.
# 
# + applicationId - The Id of the application which must be deleted
# + return - This function will return null if application is deleted from the database or else return mongodb:DatabaseError
# array index out of bound if there are no application with the specific application Id.
function deleteApplication(string applicationId) returns error? {

    // Get the application with application Id
    map<json>[]|mongodb:DatabaseError find = applicationCollection->find({"applicationId": applicationId});
    if (find is map<json>[]) {
        map<json>|error application = trap find[0];
        if (application is map<json>) {

            // Check whether it is a draft
            if (application.status == "save") {
                int|mongodb:DatabaseError delete = applicationCollection->delete({"applicationId": applicationId, "status": "save"});
                if (delete is int) {
                    return;
                }
            } else {
                return error("Invalid Operation", message = "Cannot remove submitted application");
            }
        } else {
            return application;
        }
    } else {
        return find;
    }
}
