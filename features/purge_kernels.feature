Feature: Purging old kernels that clutter /boot

  Scenario: Purging old kernels
    Given I am using the kernel "current_kernel" and have these old kernels installed:
      | old_kernel_1 |
      | old_kernel_2 |
      | old_kernel_3 |
    When I run `geordi purge-kernels`
    Then the output should contain all of these lines:
      | # Purging old kernels            |
      | > Current kernel: current_kernel |
      | > Old kernels:                   |
      | old_kernel_1                     |
      | old_kernel_2                     |
      | old_kernel_3                     |
      | > To remove these old kernels, run this command as super user: |
      | > apt-get purge old_kernel_1 old_kernel_2 old_kernel_3         |


  Scenario: Purging kernels when there are no old kernels
    Given I am using the kernel "current_kernel" and have these old kernels installed:
    When I run `geordi purge-kernels`
    Then the output should contain all of these lines:
      | # Purging old kernels            |
      | > Current kernel: current_kernel |
      | > No old kernels found.          |
