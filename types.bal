import ballerina/constraint;

enum DeliveryStatus {
    PENDING = "Pending",
    IN_TRANSIT = "In-Transit",
    DELIVERED = "Delivered"
}

type DeliveryInsert record {|
    @constraint:String {
        minLength: 5,
        maxLength: 8
    }
    string customerId;
    string customerEmail;
    decimal weightKg;
    string address;
|};

type Delivery record {|
    readonly string trackingCode;
    *DeliveryInsert;
    DeliveryStatus status = PENDING;
    decimal cost;
    string deliveredDate?;
|};

type DeliveryUpdate record {|
    DeliveryStatus status;
    string deliveredDate?;
|};

type Summary record {|
    int totalDeliveries;
    decimal averageCost;
    record {|
        int pending;
        int inTransit;
        int delivered;
    |} statusBreakdown;
|};

type PriceChart record {|
    decimal base;
    decimal perKg;
|};
