# Data Handling with Ballerina

## Introduction

In this guide, we will explore how to handle data in Ballerina, by developing a delivery tracking REST API.

The following topics will be covered:
- Modeling data as records
- Optionality
- Declarative data processing with query expressions
- Data validation
- JSON file format
- Connector usage for email notifications

The delivery tracking API consists of the following resources:

|Resource	   | Description  |
|---|---|
| POST deliveries  | Create a new delivery |
| GET deliveries[?status][?customerId]  | Get deliveries that match the filters  |
|  PATCH deliveries/{trackingCode} |  Update the delivery status |
| GET summary |  Get the summary of the deliveries |
| GET monitor |  Get the current status of the deliveries from external sources |

## Prerequisites

- Install the latest [Ballerina Swan Lake distribution](https://ballerina.io/downloads/)
- Set up [Visual Studio code](https://code.visualstudio.com/) by installing the [Ballerina extension](https://ballerina.io/learn/vs-code-extension/)


## Session

1. Create a new Ballerina project
    ``` bash
    bal new data-handling
    ```

2. Create a new Ballerina service with the base path `/delivery-tracking`

3. Define an enum to represent the delivery status. The enum should have the following values: `Pending`, `In-Transit`, and `Delivered`.

4. Define a Ballerina record to represent the delivery data coming from the client. Ensure that the `customerId` field has minimum 5 characters and maximum 8 characters. You can use the following json object as a reference. 

    ```json
    {
        "customerId": "CU0001",
        "customerEmail": "johndoe@gmail.com",
        "address": "123, Main Street, City",
        "weightKg": 10.0
    }
    ```

5. Define another record to represent the delivery data with all the internal details. Make sure to make deliveredDate nullable. Instead of defining the record from scratch, you can use type inclusion to reuse the previously defined record. You can use the following json object as a reference. 

    ```json
    {
        "trackingCode": "fa496458-03e4-4418-8533-73e38f144dd0",
        "status": "Delivered",
        "cost": 700.00,
        "customerId": "CU0001",
        "customerEmail": "johndoe@gmail.com",
        "weightKg": 10.0,
        "address": "123, Main Street, City",
        "deliveredDate": "2023-07-25"
    }
    ```

6. Create a table to store the deliveries. Use the `trackingCode` as the key.
7. Implement a method to calculate the delivery cost based on the weight. The cost is calculated as follows.
    ```ballerina
        cost = baseCost + (weightKg * costPerKg)
    ```
    Define `baseCost` and `costPerKg` as configurables in a separate `config.bal` file.

8. Implement the `POST deliveries` resource to create a new delivery. The resource should:
   - Generate a random UUID as the tracking code.
   - Calculate the cost using the previously defined method.
   - Insert the delivery into the table.
   - Return the created delivery.

9. Implement the `GET deliveries[?status][?customerId]` resource to retrieve deliveries based on the optional filters. The resource should:
   - Filter the deliveries based on the `status` and `customerId` if provided.
   - Return the filtered deliveries.

10. Implement the `PATCH deliveries/{trackingCode}` resource to update the delivery status. The body of the request should contain the new status and optionally the `deliveredDate`, if the status is `Delivered`.

    ```json
    {
        "status": "Delivered",
        "deliveredDate": "2023-07-25"
    }
    ```

    The resource should:

   - Check if the delivery exists using the `trackingCode`.
   - Return the updated delivery or a `404 Not Found` error if the delivery does not exist.
   - If the delivery exists, update the status and set the `deliveredDate` if the status is `Delivered`.
   - Send an email using the `ballerinax/googleapis.gmail` connector to notify the customer about the delivery status update. The email should include the tracking code and the new status.

11. Implement the `GET summary` resource to get the summary of the deliveries. Try to use query expressions to declaratively generate the summary. You can use the following json object as a reference for the response.

    ```json
    {
        "totalDeliveries": 10,
        "averageCost": 500.00,
        "statusBreakdown": {
            "Pending": 5,
            "In Transit": 3,
            "Delivered": 2
        }
    }
    ```

12. Implement the `GET monitor` resource to get the current status of the deliveries from external sources. Assume there are 2 external carrier services that provide tracking information in different formats. 

    - `Carrier A` provides the tracking information in a JSON file format. Please save the below JSON in `resources/carrier-a.json`.

    ```json
    [
        {
            "code": "3fa85f64-5717-4562-b3fc-2c963f66afa6",
            "lastUpdate": "2025-07-19T07:30:00Z",
            "location": "7.8731,80.7718"
        },
        {
            "code": "6b1f23f1-e204-4641-a660-0b71e382f9ac",
            "lastUpdate": "2025-07-19T10:15:00Z",
            "location": "6.9271,79.8612"
        },
        {
            "code": "b6212e32-5742-4b18-bf58-8e52f3e47651",
            "lastUpdate": "2025-07-18T18:00:00Z",
            "location": "7.1603,80.5938"
        }
    ]
    ```

    - `Carrier B` provides the tracking information in an XML file format. Please save the below XML in `resources/carrier-b.xml`.

    ```xml
    <Trackings>
        <Tracking>
            <code>fa496458-03e4-4418-8533-73e38f144dd0</code>
            <lastUpdate>2025-07-19T08:45:00Z</lastUpdate>
            <location>6.9271,79.8612</location>
        </Tracking>
        <Tracking>
            <code>88f88432-b2f5-4766-8744-5ab07b32f65e</code>
            <lastUpdate>2025-07-19T09:10:00Z</lastUpdate>
            <location>7.2906,80.6337</location>
        </Tracking>
        <Tracking>
            <code>11ab9c35-1a6f-4aa1-bd52-0a6aaff2e7dc</code>
            <lastUpdate>2025-07-18T17:30:00Z</lastUpdate>
            <location>6.0535,80.2210</location>
        </Tracking>
    </Trackings>
    ```

    Parse the JSON and XML data into Ballerina records and merge them with the existing deliveries in the table. Return the merged data as a response. You may use `ballerina/data.jsondata` and `ballerina/data.xmldata` modules to parse the data.
