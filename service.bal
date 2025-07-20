import ballerina/http;
import ballerina/io;
import ballerina/uuid;
import ballerinax/googleapis.gmail;
import ballerina/data.jsondata;
import ballerina/data.xmldata;

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
        decimal cost = basePrice + perKg * deliveryInsert.weightKg;
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

    resource function get monitor() returns Tracking[]|error {
        json carrierAJson = check io:fileReadJson("./resources/carrier-a.json");
        Tracking[] trackings = check jsondata:parseAsType(carrierAJson);
        xml carrierBXml = check io:fileReadXml("./resources/carrier-b.xml");
        Trackings xmlTrackings = check xmldata:parseAsType(carrierBXml);
        trackings.push(...xmlTrackings.Tracking);
        return trackings;
    }
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
