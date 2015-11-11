/**
 * New Relic agent configuration.
 *
 * See lib/config.defaults.js in the agent distribution for a more complete
 * description of configuration variables and their potential values.
 */
exports.config = {
  /**
   * Array of application names.
   */
  app_name : ['imgflo'],
  /**
   * Your New Relic license key.
   */
  license_key : process.env.NEW_RELIC_LICENSE_KEY,
  logging : {
    /**
     * Level at which to log. 'trace' is most useful to New Relic when diagnosing
     * issues with the agent, 'info' and higher will impose the least overhead on
     * production applications.
     */
    level : 'info'
  },
  /**
   * Don't report certain types of failures as errors
   */
  error_collector : {
    enabled : true,
    ignore_status_codes : [403,404,504]
  }
};
