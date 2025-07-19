import ballerina/http;
import ballerina/io;
import ballerina/uuid;
import ballerinax/googleapis.gmail;

table<Delivery> key(trackingCode) deliveryTable = table [];

final gmail:Client gmailClient = check new gmail:Client(
    config = {auth: {
        refreshToken,
        clientId,
        clientSecret
    }}
);

service /delivery\-tracking on new http:Listener(9090) {

    resource function post deliveries(DeliveryInsert deliveryInsert) returns Delivery|error {
        string trackingCode = uuid:createRandomUuid();
        decimal cost = check calculateCost(deliveryInsert.weightKg);
        Delivery delivery = {
            trackingCode,
            cost,
            ...deliveryInsert
        };
        deliveryTable.put(delivery);
        return delivery;
    }

    resource function get deliveries(string? status, string? customerId) returns Delivery[] {
        return deliveryTable
        .filter(delivery => status is () || status == delivery.status)
        .filter(delivery => customerId is () || customerId == delivery.customerId)
        .toArray();
    }

    resource function patch deliveries/[string trackingCode](DeliveryUpdate deliveryUpdate) returns Delivery|http:NotFound|error {
        Delivery? delivery = deliveryTable[trackingCode];
        if delivery is () {
            return http:NOT_FOUND;
        }
        delivery.status = deliveryUpdate.status;
        if deliveryUpdate.status == DELIVERED {
            delivery.deliveredDate = deliveryUpdate.deliveredDate;
        }
        check notifyCustomer(delivery);
        return delivery;
    }

    resource function get summary() returns Summary {
        int totalDeliveries = deliveryTable.length();
        decimal averageCost = from var {cost} in deliveryTable
            collect avg(cost) ?: 0d;
        int pendingCount = from var {status} in deliveryTable
            where status == PENDING
            collect count(status);
        int inTransitCount = from var {status} in deliveryTable
            where status == IN_TRANSIT
            collect count(status);
        int deliveredCount = from var {status} in deliveryTable
            where status == DELIVERED
            collect count(status);
        return {
            totalDeliveries,
            averageCost,
            statusBreakdown: {pending: pendingCount, inTransit: inTransitCount, delivered: deliveredCount}
        };
    }
}

function calculateCost(decimal weightKg) returns decimal|error {
    json priceData = check io:fileReadJson("./resources/charges.json");
    PriceChart PriceChart = check priceData.fromJsonWithType();
    return PriceChart.base + weightKg * PriceChart.perKg;
}

function notifyCustomer(Delivery delivery) returns error? {
    gmail:MessageRequest message = {
        to: [delivery.customerEmail],
        subject: "Delivery Status Update",
        bodyInHtml: string `<html>
                            <head>
                                <title>The status of your delivery ${delivery.trackingCode} has been updated to ${delivery.status}.</title>
                            </head>
                        </html>`
    };
    gmail:Message _ = check gmailClient->/users/me/messages/send.post(message);
}
