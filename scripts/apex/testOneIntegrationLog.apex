
/**
 *   public static void publishInfo(String context, String message, String stackTrace, String payloadId, String jobId) {
        publishError(
            context,
            message,
            stackTrace,
            payloadId,
            jobId,
            true
        );
    }
 */

IntegrationEventPublisher.publishInfo(
    'Direcciones',
    'Single test log for integration health dashboard',
    '{Really long stack trace details here... jnrtgnjrfgnjrgnjfnjrfgnjnjaewjnfj Really long stack trace details here... jnrtgnjrfgnjrgnjfnjrfgnjnjaewjnfj Really long stack trace details here... jnrtgnjrfgnjrgnjfnjrfgnjnjaewjnfj Really long stack trace details here... jnrtgnjrfgnjrgnjfnjrfgnjnjaewjnfj Really long stack trace details here... jnrtgnjrfgnjrgnjfnjrfgnjnjaewjnfj Really long stack trace details here... jnrtgnjrfgnjrgnjfnjrfgnjnjaewjnfj Really long stack trace details here... jnrtgnjrfgnjrgnjfnjrfgnjnjaewjnfj Really long stack trace details here... jnrtgnjrfgnjrgnjfnjrfgnjnjaewjnfj Really long stack trace details here... jnrtgnjrfgnjrgnjfnjrfgnjnjaewjnfj Really long stack trace details here... jnrtgnjrfgnjrgnjfnjrfgnjnjaewjnfj Really long stack trace details here... jnrtgnjrfgnjrgnjfnjrfgnjnjaewjnfj }',
    'PAYLOAD_ONE_TEST_' + String.valueOf(Datetime.now().getTime()),
    'JOB_ONE_TEST'
);
IntegrationEventPublisher.publishError(
    'Headless_Registration_Batch_Exec',
    'Single test log for integration health dashboard',
    null,
    'PAYLOAD_ONE_TEST_' + String.valueOf(Datetime.now().getTime()),
    'JOB_ONE_TEST'
);