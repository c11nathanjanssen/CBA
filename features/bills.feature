Feature: Bills
  In order to participate in the political process
  As any user
  I want list and interact with Bills

Scenario: Guest should be able to see a list of bills
  Given I am on the bills page
  Then I should see a list of all current Bills

