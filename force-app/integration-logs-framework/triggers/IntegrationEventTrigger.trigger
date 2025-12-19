trigger IntegrationEventTrigger on IntegrationEvent__e (after insert) {
    IntegrationLogHandler.handleEvents(Trigger.new);
}
